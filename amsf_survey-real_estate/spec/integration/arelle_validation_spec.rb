# frozen_string_literal: true

require "spec_helper"
require_relative "../support/arelle_helper"

RSpec.describe "Arelle XBRL Validation", :arelle do
  include ArelleHelper

  before(:all) do
    skip "Arelle API not available" unless arelle_available?
  end

  def build_submission(data = {})
    submission = AmsfSurvey::Submission.new(
      industry: :real_estate,
      year: 2025,
      entity_id: "RE_TEST_001",
      period: Date.new(2025, 12, 31)
    )
    data.each { |k, v| submission[k] = v }
    submission
  end

  describe "arelle integration" do
    it "successfully validates XBRL against arelle_api" do
      submission = build_submission({})

      xml = AmsfSurvey.to_xbrl(submission, include_empty: false)
      result = validate_xbrl(xml)

      # Verify we got a valid response structure
      expect(result).to have_key("valid")
      expect(result).to have_key("messages")

      # Empty submission will have validation errors - that's expected
      # This test verifies the integration works, not that empty data is valid
      if result["valid"]
        puts "\nXBRL is valid!"
      else
        error_count = result["messages"].count { |m| m["severity"] == "error" }
        puts "\nArelle returned #{error_count} validation errors (expected for empty submission)"
      end
    end
  end

  describe "inactive entity (aACTIVE = Non)" do
    it "generates valid XBRL for inactive entity" do
      # Minimal valid submission: entity not active in reporting period
      # These fields are unconditionally required regardless of aACTIVE:
      # - Section 1.12: a14801 (Comments & Feedback - gate question)
      # - Section 3.1: a3101, a3103 (Identification - reliance on third parties)
      # - Section 3.2: a3201, a3209, a3210, a3210B (Onboarding)
      # - Section 3.3: a3301 (Structure - number of personnel)
      submission = build_submission(
        aACTIVE: "Non",
        # Section 1.12: Comments & Feedback
        a14801: "Non",      # Q110: Has feedback about section 1?
        # Section 3.1: Identification
        a3101: "Non",       # Q168: Rely on third parties for CDD?
        a3103: "Non",       # Q170: Rely on third parties for CDD identification?
        # Section 3.2: Onboarding
        a3201: "Non",       # Q173: Did you reject any clients?
        a3209: "Non",       # Q181: Use introducers?
        a3210: "Non",       # Q182: Use delegated CDD?
        a3210B: "Non",      # Q183: Delegate CDD to external parties?
        # Section 3.3: Structure
        a3301: 1            # Q189: Number of personnel employed
      )

      xml = AmsfSurvey.to_xbrl(submission, include_empty: false)
      result = validate_xbrl(xml)

      unless result["valid"]
        puts "\n=== Arelle Validation Errors ==="
        result["messages"].each do |msg|
          next if msg["severity"] == "info"
          puts "#{msg['severity'].upcase}: #{msg['message']}"
        end
        puts "================================\n"
      end

      expect(result["valid"]).to be true
    end
  end

  describe "active entity (aACTIVE = Oui)" do
    it "reports missing required fields for incomplete active entity" do
      # Active entity without all required fields - XULE enforces many fields
      submission = build_submission(
        aACTIVE: "Oui",
        # Unconditionally required fields (not enough for aACTIVE = Oui)
        a14801: "Non",
        a3101: "Non",
        a3103: "Non",
        a3201: "Non",
        a3209: "Non",
        a3210: "Non",
        a3210B: "Non",
        a3301: 1
      )

      xml = AmsfSurvey.to_xbrl(submission, include_empty: false)
      result = validate_xbrl(xml)

      # XULE rules require ~40 additional fields when aACTIVE is Oui
      # This verifies XULE validation is working correctly
      expect(result["valid"]).to be false
      expect(result["summary"]["errors"]).to be > 30

      # Verify specific required field errors are reported
      error_messages = result["messages"].select { |m| m["severity"] == "error" }.map { |m| m["message"] }
      expect(error_messages).to include(match(/a1101 should be present/))
      expect(error_messages).to include(match(/aACTIVEPS should be present/))
    end

    it "validates sum-of-children constraint" do
      # Test the sum validation rule: a1101 >= a1102 + a1103 + a1104 + a1501 + a1802TOLA
      submission = build_submission(
        aACTIVE: "Oui",
        a1101: 5,                # Total clients = 5
        a1102: 3,                # Monaco nationals = 3
        a1103: 2,                # Monaco residents = 2
        a1104: 2,                # Non-residents = 2
        a1501: 2,                # Legal persons = 2
        a1802TOLA: 1,            # TOLA = 1
        # Sum = 3+2+2+2+1 = 10 > 5 (invalid!)
        # Unconditionally required fields
        a14801: "Non",
        a3101: "Non",
        a3103: "Non",
        a3201: "Non",
        a3209: "Non",
        a3210: "Non",
        a3210B: "Non",
        a3301: 1
      )

      xml = AmsfSurvey.to_xbrl(submission, include_empty: false)
      result = validate_xbrl(xml)

      # Should detect sum constraint violation
      error_messages = result["messages"].select { |m| m["severity"] == "error" }.map { |m| m["message"] }
      expect(error_messages).to include(match(/Sum of children.*more than the parent/))
    end
  end

  describe "dimensional facts (country breakdowns)" do
    it "validates XBRL with dimensional country breakdown facts" do
      # Test dimensional fields - a1204S1 is a percentage breakdown by country
      # (Percentage of high-risk clients by country)
      submission = build_submission(
        aACTIVE: "Oui",
        # Dimensional breakdown: a1204S1 with country dimension
        a1204S1: { "FR" => 40.0, "MC" => 30.0, "IT" => 30.0 },
        # Unconditionally required fields
        a14801: "Non",
        a3101: "Non",
        a3103: "Non",
        a3201: "Non",
        a3209: "Non",
        a3210: "Non",
        a3210B: "Non",
        a3301: 1
      )

      xml = AmsfSurvey.to_xbrl(submission, include_empty: false)

      # Verify dimensional contexts are generated in the XML
      doc = Nokogiri::XML(xml)
      contexts = doc.xpath("//xbrli:context", "xbrli" => "http://www.xbrl.org/2003/instance")

      # Should have base context + dimensional contexts for each country
      expect(contexts.size).to be >= 4 # base + FR + MC + IT

      # Verify dimensional facts reference correct contexts
      result = validate_xbrl(xml)

      # Log any dimensional-related errors for debugging
      dim_errors = result["messages"].select do |m|
        m["severity"] == "error" && m["message"].to_s.match?(/dimension|context|a1204S1/i)
      end

      if dim_errors.any?
        puts "\n=== Dimensional Validation Errors ==="
        dim_errors.each { |e| puts "ERROR: #{e['message']}" }
        puts "=====================================\n"
      end

      # The submission may have other errors (missing fields for active entity)
      # but should not have dimensional structure errors
      expect(dim_errors).to be_empty, "Expected no dimensional errors, got: #{dim_errors.map { |e| e['message'] }}"
    end

    it "handles normalized country codes correctly" do
      # Test that lowercase country codes are normalized to uppercase
      # and generate valid XBRL dimension members
      # Using a1204S1 which is a dimensional percentage field
      submission = build_submission(
        aACTIVE: "Non",
        # Use lowercase codes - should be normalized to uppercase
        a1204S1: { "fr" => 50.0, "de" => 50.0 },
        # Unconditionally required fields
        a14801: "Non",
        a3101: "Non",
        a3103: "Non",
        a3201: "Non",
        a3209: "Non",
        a3210: "Non",
        a3210B: "Non",
        a3301: 1
      )

      xml = AmsfSurvey.to_xbrl(submission, include_empty: false)

      # Verify country codes are uppercase in the XML
      expect(xml).to include("sdlFR")
      expect(xml).to include("sdlDE")
      expect(xml).not_to include("sdlfr")
      expect(xml).not_to include("sdlde")

      result = validate_xbrl(xml)

      # Check for dimension member validation errors
      member_errors = result["messages"].select do |m|
        m["severity"] == "error" && m["message"].to_s.match?(/member|sdl/i)
      end

      expect(member_errors).to be_empty, "Expected valid dimension members, got: #{member_errors.map { |e| e['message'] }}"
    end

    it "validates dimensional field with many countries" do
      # Test a dimensional field with many countries to ensure context generation scales
      submission = build_submission(
        aACTIVE: "Oui",
        # Dimensional percentage field with 5 countries
        a1204S1: {
          "FR" => 25.0,
          "DE" => 20.0,
          "IT" => 20.0,
          "ES" => 20.0,
          "PT" => 15.0
        },
        # Unconditionally required fields
        a14801: "Non",
        a3101: "Non",
        a3103: "Non",
        a3201: "Non",
        a3209: "Non",
        a3210: "Non",
        a3210B: "Non",
        a3301: 1
      )

      xml = AmsfSurvey.to_xbrl(submission, include_empty: false)
      doc = Nokogiri::XML(xml)

      # Count contexts: 1 base + 5 dimensional
      contexts = doc.xpath("//xbrli:context", "xbrli" => "http://www.xbrl.org/2003/instance")
      expect(contexts.size).to eq(6)

      # Verify each country has exactly one fact
      %w[FR DE IT ES PT].each do |country|
        country_facts = doc.xpath("//*[contains(@contextRef, '_#{country}')]")
        expect(country_facts.size).to eq(1), "Expected 1 fact for #{country}, got #{country_facts.size}"
      end

      result = validate_xbrl(xml)

      # Should not have dimensional structure errors
      dim_errors = result["messages"].select do |m|
        m["severity"] == "error" && m["message"].to_s.match?(/dimension|context/i)
      end

      expect(dim_errors).to be_empty, "Expected no dimensional errors, got: #{dim_errors.map { |e| e['message'] }}"
    end
  end
end
