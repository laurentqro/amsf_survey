# frozen_string_literal: true

require "bigdecimal"

RSpec.describe "Submission and Validation Integration" do
  # Create a realistic questionnaire structure
  let(:fields) do
    [
      AmsfSurvey::Field.new(
        id: :total_unique_clients,
        name: :total_unique_clients,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        source_type: :entry_only,
        label: "Total Unique Clients",
        section_id: :section1,
        order: 1,
        gate: false
      ),
      AmsfSurvey::Field.new(
        id: :national_individuals,
        name: :national_individuals,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        source_type: :entry_only,
        label: "National Individuals",
        section_id: :section1,
        order: 2,
        gate: false
      ),
      AmsfSurvey::Field.new(
        id: :transaction_amount,
        name: :transaction_amount,
        type: :monetary,
        xbrl_type: "xbrli:monetaryItemType",
        source_type: :prefillable,
        label: "Transaction Amount",
        section_id: :section1,
        order: 3,
        gate: false
      ),
      AmsfSurvey::Field.new(
        id: :acted_as_professional_agent,
        name: :acted_as_professional_agent,
        type: :boolean,
        xbrl_type: "xbrli:booleanItemType",
        source_type: :entry_only,
        label: "Acted as Professional Agent",
        section_id: :section2,
        order: 1,
        gate: true,
        valid_values: %w[Oui Non]
      ),
      AmsfSurvey::Field.new(
        id: :rental_transaction_count,
        name: :rental_transaction_count,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        source_type: :entry_only,
        label: "Rental Transaction Count",
        section_id: :section2,
        order: 2,
        gate: false,
        depends_on: { acted_as_professional_agent: "Oui" }
      ),
      AmsfSurvey::Field.new(
        id: :high_risk_percentage,
        name: :high_risk_percentage,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        source_type: :entry_only,
        label: "High Risk Percentage",
        section_id: :section3,
        order: 1,
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

  describe "complete workflow from spec quickstart.md" do
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

    it "validates a complete submission" do
      submission = AmsfSurvey::Submission.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      submission[:total_unique_clients] = 50
      submission[:national_individuals] = 30
      submission[:transaction_amount] = "1000.00"
      submission[:acted_as_professional_agent] = "Non"
      submission[:high_risk_percentage] = 25

      result = AmsfSurvey.validate(submission)

      expect(result.valid?).to be true
      expect(result.complete?).to be true
      expect(result.errors).to be_empty
    end

    it "detects validation errors" do
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
      submission[:high_risk_percentage] = 150 # Invalid range

      result = AmsfSurvey.validate(submission)

      expect(result.valid?).to be false
      expect(result.complete?).to be false

      # Check for presence errors
      missing_fields = result.errors.select { |e| e.rule == :presence }.map(&:field)
      expect(missing_fields).to include(:national_individuals, :transaction_amount, :rental_transaction_count)

      # Check for range error
      range_error = result.errors.find { |e| e.rule == :range }
      expect(range_error).not_to be_nil
      expect(range_error.field).to eq(:high_risk_percentage)
      expect(range_error.context[:value]).to eq(150)
      expect(range_error.context[:max]).to eq(100)
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

    it "validates boolean field values" do
      submission[:total_unique_clients] = 50
      submission[:national_individuals] = 30
      submission[:transaction_amount] = "1000.00"
      submission[:high_risk_percentage] = 25
      submission[:acted_as_professional_agent] = "Maybe"

      result = AmsfSurvey.validate(submission)

      enum_error = result.errors.find { |e| e.field == :acted_as_professional_agent && e.rule == :enum }
      expect(enum_error).not_to be_nil
      expect(enum_error.context[:valid_values]).to eq(%w[Oui Non])
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
