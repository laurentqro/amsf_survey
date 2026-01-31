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

      xml = AmsfSurvey.to_xbrl(submission)
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

  describe "discovery: minimal valid submission", :pending do
    # This test is for discovering what fields are required
    # Run it manually during development: ARELLE=1 bundle exec rspec -e "discovery"
    it "discovers required fields by attempting validation" do
      submission = build_submission({})

      xml = AmsfSurvey.to_xbrl(submission)
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
end
