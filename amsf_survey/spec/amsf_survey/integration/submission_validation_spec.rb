# frozen_string_literal: true

require "bigdecimal"

RSpec.describe "Submission Integration" do
  # Create a realistic questionnaire structure
  let(:fields) do
    [
      AmsfSurvey::Field.new(
        id: :total_unique_clients,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        label: "Total Unique Clients",
        section_id: :section1,
        gate: false
      ),
      AmsfSurvey::Field.new(
        id: :national_individuals,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        label: "National Individuals",
        section_id: :section1,
        gate: false
      ),
      AmsfSurvey::Field.new(
        id: :transaction_amount,
        type: :monetary,
        xbrl_type: "xbrli:monetaryItemType",
        label: "Transaction Amount",
        section_id: :section1,
        gate: false
      ),
      AmsfSurvey::Field.new(
        id: :acted_as_professional_agent,
        type: :boolean,
        xbrl_type: "xbrli:booleanItemType",
        label: "Acted as Professional Agent",
        section_id: :section2,
        gate: true,
        valid_values: %w[Oui Non]
      ),
      AmsfSurvey::Field.new(
        id: :rental_transaction_count,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        label: "Rental Transaction Count",
        section_id: :section2,
        gate: false,
        depends_on: { acted_as_professional_agent: "Oui" }
      ),
      AmsfSurvey::Field.new(
        id: :high_risk_percentage,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        label: "High Risk Percentage",
        section_id: :section3,
        gate: false
      )
    ]
  end

  let(:section1) do
    AmsfSurvey::Section.new(
      id: :section1,
      name: "Client Information",
      order: 1,
      fields: fields.select { |f| f.section_id == :section1 }
    )
  end

  let(:section2) do
    AmsfSurvey::Section.new(
      id: :section2,
      name: "Professional Activities",
      order: 2,
      fields: fields.select { |f| f.section_id == :section2 }
    )
  end

  let(:section3) do
    AmsfSurvey::Section.new(
      id: :section3,
      name: "Risk Assessment",
      order: 3,
      fields: fields.select { |f| f.section_id == :section3 }
    )
  end

  let(:questionnaire) do
    AmsfSurvey::Questionnaire.new(
      industry: :real_estate,
      year: 2025,
      sections: [section1, section2, section3]
    )
  end

  before do
    allow(AmsfSurvey).to receive(:questionnaire)
      .with(industry: :real_estate, year: 2025)
      .and_return(questionnaire)
  end

  describe "complete workflow" do
    it "creates and populates a submission" do
      submission = AmsfSurvey::Submission.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      # Set values using bracket notation
      submission[:total_unique_clients] = 50
      submission[:national_individuals] = 30
      submission[:transaction_amount] = "1234.56"
      submission[:acted_as_professional_agent] = "Oui"
      submission[:rental_transaction_count] = 10
      submission[:high_risk_percentage] = 25

      # Verify type casting
      expect(submission[:total_unique_clients]).to eq(50)
      expect(submission[:transaction_amount]).to be_a(BigDecimal)
      expect(submission[:transaction_amount]).to eq(BigDecimal("1234.56"))

      # Verify completeness
      expect(submission.complete?).to be true
      expect(submission.missing_fields).to be_empty
      expect(submission.completion_percentage).to eq(100.0)
    end

    it "tracks incomplete submissions" do
      submission = AmsfSurvey::Submission.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      # Missing required fields
      submission[:total_unique_clients] = 50
      submission[:acted_as_professional_agent] = "Oui"
      # rental_transaction_count is now required but missing
      submission[:high_risk_percentage] = 150

      expect(submission.complete?).to be false
      expect(submission.missing_fields).to include(
        :national_individuals, :transaction_amount, :rental_transaction_count
      )
    end
  end

  describe "edge cases" do
    let(:submission) do
      AmsfSurvey::Submission.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )
    end

    it "handles nil values correctly" do
      submission[:total_unique_clients] = 50
      submission[:total_unique_clients] = nil

      expect(submission[:total_unique_clients]).to be_nil
      expect(submission.missing_fields).to include(:total_unique_clients)
    end

    it "handles empty strings for integer fields" do
      submission[:total_unique_clients] = ""
      expect(submission[:total_unique_clients]).to be_nil
    end

    it "raises UnknownFieldError for invalid fields" do
      expect {
        submission[:nonexistent_field] = 100
      }.to raise_error(AmsfSurvey::UnknownFieldError, "Unknown field: nonexistent_field")
    end

    it "respects gate visibility in completeness" do
      # Gate closed - rental_transaction_count should not be required
      submission[:acted_as_professional_agent] = "Non"

      expect(submission.missing_fields).not_to include(:rental_transaction_count)

      # Gate open - rental_transaction_count is now required
      submission[:acted_as_professional_agent] = "Oui"

      expect(submission.missing_fields).to include(:rental_transaction_count)
    end
  end

  describe "data hash access" do
    it "returns all set values" do
      submission = AmsfSurvey::Submission.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      submission[:total_unique_clients] = 50
      submission[:acted_as_professional_agent] = "Oui"

      expect(submission.data).to eq({
        total_unique_clients: 50,
        acted_as_professional_agent: "Oui"
      })
    end
  end
end
