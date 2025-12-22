# frozen_string_literal: true

require "bigdecimal"

RSpec.describe AmsfSurvey::Validator do
  # Mock fields for testing
  let(:required_field) do
    AmsfSurvey::Field.new(
      id: :total_clients,
      name: :total_clients,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      source_type: :entry_only,
      label: "Total Clients",
      section_id: :general,
      order: 1,
      gate: false
    )
  end

  let(:percentage_field) do
    AmsfSurvey::Field.new(
      id: :high_risk_percentage,
      name: :high_risk_percentage,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      source_type: :entry_only,
      label: "High Risk Percentage",
      section_id: :general,
      order: 2,
      gate: false
    )
  end

  let(:enum_field) do
    AmsfSurvey::Field.new(
      id: :status,
      name: :status,
      type: :enum,
      xbrl_type: "xbrli:stringItemType",
      source_type: :entry_only,
      label: "Status",
      section_id: :general,
      order: 3,
      gate: false,
      valid_values: %w[Active Inactive Pending]
    )
  end

  let(:boolean_field) do
    AmsfSurvey::Field.new(
      id: :is_agent,
      name: :is_agent,
      type: :boolean,
      xbrl_type: "xbrli:booleanItemType",
      source_type: :entry_only,
      label: "Is Agent",
      section_id: :general,
      order: 4,
      gate: true,
      valid_values: %w[Oui Non]
    )
  end

  let(:dependent_field) do
    AmsfSurvey::Field.new(
      id: :agent_details,
      name: :agent_details,
      type: :string,
      xbrl_type: "xbrli:stringItemType",
      source_type: :entry_only,
      label: "Agent Details",
      section_id: :general,
      order: 5,
      gate: false,
      depends_on: { is_agent: "Oui" }
    )
  end

  let(:computed_field) do
    AmsfSurvey::Field.new(
      id: :computed_total,
      name: :computed_total,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      source_type: :computed,
      label: "Computed Total",
      section_id: :general,
      order: 6,
      gate: false
    )
  end

  let(:section) do
    AmsfSurvey::Section.new(
      id: :general,
      name: "General Information",
      order: 1,
      fields: [required_field, percentage_field, enum_field, boolean_field, dependent_field, computed_field]
    )
  end

  let(:questionnaire) do
    AmsfSurvey::Questionnaire.new(
      industry: :real_estate,
      year: 2025,
      sections: [section]
    )
  end

  before do
    allow(AmsfSurvey).to receive(:questionnaire)
      .with(industry: :real_estate, year: 2025)
      .and_return(questionnaire)
  end

  let(:submission) do
    AmsfSurvey::Submission.new(
      industry: :real_estate,
      year: 2025,
      entity_id: "ENTITY_001",
      period: Date.new(2025, 12, 31)
    )
  end

  describe ".validate" do
    context "with valid complete submission" do
      before do
        submission[:total_clients] = 50
        submission[:high_risk_percentage] = 25
        submission[:status] = "Active"
        submission[:is_agent] = "Non"
      end

      it "returns a valid result" do
        result = described_class.validate(submission)

        expect(result).to be_a(AmsfSurvey::ValidationResult)
        expect(result.valid?).to be true
        expect(result.errors).to be_empty
      end
    end

    context "with missing required fields" do
      it "returns presence errors for missing fields" do
        result = described_class.validate(submission)

        expect(result.valid?).to be false
        expect(result.complete?).to be false

        presence_errors = result.errors.select { |e| e.rule == :presence }
        expect(presence_errors.map(&:field)).to include(:total_clients, :high_risk_percentage, :status, :is_agent)
      end

      it "excludes hidden fields from presence check" do
        submission[:is_agent] = "Non"
        # agent_details is hidden, should not be in errors

        result = described_class.validate(submission)
        expect(result.errors.map(&:field)).not_to include(:agent_details)
      end

      it "includes dependent fields when gate is satisfied" do
        submission[:is_agent] = "Oui"
        # agent_details is now visible and required

        result = described_class.validate(submission)
        expect(result.errors.map(&:field)).to include(:agent_details)
      end
    end
  end

  describe "presence validation" do
    it "creates error with correct message" do
      result = described_class.validate(submission)

      error = result.errors.find { |e| e.field == :total_clients && e.rule == :presence }
      expect(error).not_to be_nil
      expect(error.message).to eq("Field 'Total Clients' is required")
      expect(error.severity).to eq(:error)
    end
  end

  describe "range validation" do
    before do
      submission[:total_clients] = 50
      submission[:status] = "Active"
      submission[:is_agent] = "Non"
    end

    it "validates percentage fields are 0-100" do
      submission[:high_risk_percentage] = 150

      result = described_class.validate(submission)

      range_error = result.errors.find { |e| e.rule == :range }
      expect(range_error).not_to be_nil
      expect(range_error.field).to eq(:high_risk_percentage)
      expect(range_error.message).to include("at most 100")
      expect(range_error.context[:value]).to eq(150)
      expect(range_error.context[:max]).to eq(100)
    end

    it "accepts valid percentage" do
      submission[:high_risk_percentage] = 50

      result = described_class.validate(submission)

      range_errors = result.errors.select { |e| e.rule == :range }
      expect(range_errors).to be_empty
    end

    it "validates minimum is 0" do
      submission[:high_risk_percentage] = -10

      result = described_class.validate(submission)

      range_error = result.errors.find { |e| e.rule == :range }
      expect(range_error).not_to be_nil
      expect(range_error.message).to include("at least 0")
      expect(range_error.context[:min]).to eq(0)
    end
  end

  describe "enum validation" do
    before do
      submission[:total_clients] = 50
      submission[:high_risk_percentage] = 25
      submission[:is_agent] = "Non"
    end

    it "validates value is in valid_values" do
      submission[:status] = "Invalid"

      result = described_class.validate(submission)

      enum_error = result.errors.find { |e| e.rule == :enum }
      expect(enum_error).not_to be_nil
      expect(enum_error.field).to eq(:status)
      expect(enum_error.message).to include("Active, Inactive, Pending")
      expect(enum_error.context[:value]).to eq("Invalid")
      expect(enum_error.context[:valid_values]).to eq(%w[Active Inactive Pending])
    end

    it "accepts valid enum value" do
      submission[:status] = "Active"

      result = described_class.validate(submission)

      enum_errors = result.errors.select { |e| e.rule == :enum }
      expect(enum_errors).to be_empty
    end
  end

  describe "conditional validation" do
    before do
      submission[:total_clients] = 50
      submission[:high_risk_percentage] = 25
      submission[:status] = "Active"
    end

    it "requires dependent field when gate is satisfied" do
      submission[:is_agent] = "Oui"
      # agent_details is required now

      result = described_class.validate(submission)

      conditional_error = result.errors.find { |e| e.field == :agent_details && e.rule == :presence }
      expect(conditional_error).not_to be_nil
    end

    it "does not require dependent field when gate is not satisfied" do
      submission[:is_agent] = "Non"

      result = described_class.validate(submission)

      agent_errors = result.errors.select { |e| e.field == :agent_details }
      expect(agent_errors).to be_empty
    end
  end

  describe "boolean field validation" do
    before do
      submission[:total_clients] = 50
      submission[:high_risk_percentage] = 25
      submission[:status] = "Active"
    end

    it "validates boolean field value" do
      submission[:is_agent] = "Maybe"

      result = described_class.validate(submission)

      enum_error = result.errors.find { |e| e.field == :is_agent && e.rule == :enum }
      expect(enum_error).not_to be_nil
    end

    it "accepts valid boolean values" do
      submission[:is_agent] = "Oui"

      result = described_class.validate(submission)

      is_agent_errors = result.errors.select { |e| e.field == :is_agent && e.rule == :enum }
      expect(is_agent_errors).to be_empty
    end
  end

  describe "explicit range validation via Field#min/max" do
    let(:field_with_range) do
      AmsfSurvey::Field.new(
        id: :score,
        name: :score,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        source_type: :entry_only,
        label: "Score",
        section_id: :general,
        order: 7,
        gate: false,
        min: 1,
        max: 10
      )
    end

    let(:section_with_range) do
      AmsfSurvey::Section.new(
        id: :general,
        name: "General Information",
        order: 1,
        fields: [field_with_range]
      )
    end

    let(:questionnaire_with_range) do
      AmsfSurvey::Questionnaire.new(
        industry: :test,
        year: 2025,
        sections: [section_with_range]
      )
    end

    let(:submission_with_range) do
      submission = AmsfSurvey::Submission.new(
        industry: :test,
        year: 2025,
        entity_id: "TEST",
        period: Date.new(2025, 12, 31)
      )
      allow(submission).to receive(:questionnaire).and_return(questionnaire_with_range)
      submission
    end

    it "uses Field#min/max for range validation" do
      submission_with_range[:score] = 15

      result = described_class.validate(submission_with_range)

      range_error = result.errors.find { |e| e.rule == :range }
      expect(range_error).not_to be_nil
      expect(range_error.message).to include("at most 10")
      expect(range_error.context[:max]).to eq(10)
    end

    it "validates minimum from Field#min" do
      submission_with_range[:score] = 0

      result = described_class.validate(submission_with_range)

      range_error = result.errors.find { |e| e.rule == :range }
      expect(range_error).not_to be_nil
      expect(range_error.message).to include("at least 1")
      expect(range_error.context[:min]).to eq(1)
    end

    it "accepts value within explicit range" do
      submission_with_range[:score] = 5

      result = described_class.validate(submission_with_range)

      range_errors = result.errors.select { |e| e.rule == :range }
      expect(range_errors).to be_empty
    end

    it "prefers explicit range over percentage heuristic" do
      # Field named 'percentage' but with explicit range 1-10
      field_with_explicit = AmsfSurvey::Field.new(
        id: :custom_percentage,
        name: :custom_percentage,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        source_type: :entry_only,
        label: "Custom Percentage",
        section_id: :general,
        order: 1,
        gate: false,
        min: 1,
        max: 10
      )

      section = AmsfSurvey::Section.new(
        id: :general,
        name: "General",
        order: 1,
        fields: [field_with_explicit]
      )

      questionnaire = AmsfSurvey::Questionnaire.new(
        industry: :test,
        year: 2025,
        sections: [section]
      )

      sub = AmsfSurvey::Submission.new(
        industry: :test,
        year: 2025,
        entity_id: "TEST",
        period: Date.new(2025, 12, 31)
      )
      allow(sub).to receive(:questionnaire).and_return(questionnaire)

      # Value 50 would be valid if using 0-100 heuristic, but invalid for 1-10
      sub[:custom_percentage] = 50

      result = described_class.validate(sub)

      range_error = result.errors.find { |e| e.rule == :range }
      expect(range_error).not_to be_nil
      expect(range_error.context[:max]).to eq(10) # Uses explicit range, not 100
    end
  end
end
