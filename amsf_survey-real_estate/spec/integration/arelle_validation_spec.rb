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
    it "validates minimal active entity" do
      # Active entity with no specific activity data
      submission = build_submission(
        aACTIVE: "Oui",
        # Section 1.12: Comments & Feedback
        a14801: "Non",
        # Section 3.1: Identification
        a3101: "Non",
        a3103: "Non",
        # Section 3.2: Onboarding
        a3201: "Non",
        a3209: "Non",
        a3210: "Non",
        a3210B: "Non",
        # Section 3.3: Structure
        a3301: 1
      )

      xml = AmsfSurvey.to_xbrl(submission, include_empty: false)
      result = validate_xbrl(xml)

      unless result["valid"]
        puts "\n=== Active Entity Validation Errors ==="
        result["messages"].each do |msg|
          next if msg["severity"] == "info"
          puts "#{msg['severity'].upcase}: #{msg['message']}"
        end
        puts "========================================\n"
      end

      expect(result["valid"]).to be true
    end

    it "validates active entity with client data" do
      # Active entity with complete client breakdown
      # Note: XULE formula validation (cross-field rules) requires additional
      # Arelle configuration. This test validates XBRL schema compliance.
      submission = build_submission(
        aACTIVE: "Oui",
        a1101: 10,               # Total unique clients
        a1102: 3,                # Natural persons - Monaco nationals
        a1103: 4,                # Natural persons - Monaco residents
        a1104: 2,                # Natural persons - non-residents
        a1501: 1,                # Legal persons
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

      unless result["valid"]
        puts "\n=== Active Entity With Clients - Validation Errors ==="
        result["messages"].each do |msg|
          next if msg["severity"] == "info"
          puts "#{msg['severity'].upcase}: #{msg['message']}"
        end
        puts "=====================================================\n"
      end

      expect(result["valid"]).to be true
    end
  end
end
