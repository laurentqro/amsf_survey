# frozen_string_literal: true

require "bigdecimal"

RSpec.describe AmsfSurvey::Submission do
  # Mock questionnaire and fields for testing
  let(:integer_field) do
    AmsfSurvey::Field.new(
      id: :total_clients,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      label: "Total Clients",
      section_id: :general,
      gate: false
    )
  end

  let(:monetary_field) do
    AmsfSurvey::Field.new(
      id: :total_amount,
      type: :monetary,
      xbrl_type: "xbrli:monetaryItemType",
      label: "Total Amount",
      section_id: :general,
      gate: false
    )
  end

  let(:boolean_field) do
    AmsfSurvey::Field.new(
      id: :is_agent,
      type: :boolean,
      xbrl_type: "xbrli:booleanItemType",
      label: "Is Agent",
      section_id: :general,
      gate: true,
      valid_values: %w[Oui Non]
    )
  end

  let(:dependent_field) do
    AmsfSurvey::Field.new(
      id: :agent_details,
      type: :string,
      xbrl_type: "xbrli:stringItemType",
      label: "Agent Details",
      section_id: :general,
      gate: false,
      depends_on: { is_agent: "Oui" }
    )
  end

  let(:computed_field) do
    AmsfSurvey::Field.new(
      id: :computed_total,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      label: "Computed Total",
      section_id: :general,
      gate: false
    )
  end

  # Wrap fields in Questions
  let(:q1) { AmsfSurvey::Question.new(number: 1, field: integer_field, instructions: nil) }
  let(:q2) { AmsfSurvey::Question.new(number: 2, field: monetary_field, instructions: nil) }
  let(:q3) { AmsfSurvey::Question.new(number: 3, field: boolean_field, instructions: nil) }
  let(:q4) { AmsfSurvey::Question.new(number: 4, field: dependent_field, instructions: nil) }
  let(:q5) { AmsfSurvey::Question.new(number: 5, field: computed_field, instructions: nil) }

  # Create subsection and section
  let(:subsection) do
    AmsfSurvey::Subsection.new(
      number: 1,
      title: "General Info",
      questions: [q1, q2, q3, q4, q5]
    )
  end

  let(:section) do
    AmsfSurvey::Section.new(
      number: 1,
      title: "General Information",
      subsections: [subsection]
    )
  end

  let(:questionnaire) do
    AmsfSurvey::Questionnaire.new(
      industry: :real_estate,
      year: 2025,
      sections: [section]
    )
  end

  # Stub the Registry to return our mock questionnaire
  before do
    allow(AmsfSurvey).to receive(:questionnaire)
      .with(industry: :real_estate, year: 2025)
      .and_return(questionnaire)
  end

  describe "#initialize" do
    it "creates a submission with required attributes" do
      submission = described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      expect(submission.industry).to eq(:real_estate)
      expect(submission.year).to eq(2025)
      expect(submission.entity_id).to eq("ENTITY_001")
      expect(submission.period).to eq(Date.new(2025, 12, 31))
    end

    it "starts with empty data hash" do
      submission = described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      expect(submission.data).to eq({})
    end
  end

  describe "#questionnaire" do
    it "returns the questionnaire for industry and year" do
      submission = described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      expect(submission.questionnaire).to eq(questionnaire)
    end

    it "caches the questionnaire" do
      submission = described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      # First access
      q1 = submission.questionnaire
      # Second access - should return same instance
      q2 = submission.questionnaire

      expect(AmsfSurvey).to have_received(:questionnaire).once
      expect(q1).to equal(q2)
    end
  end

  describe "#[]=" do
    let(:submission) do
      described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )
    end

    context "type casting" do
      it "casts string to integer for integer fields" do
        submission[:total_clients] = "50"
        expect(submission[:total_clients]).to eq(50)
      end

      it "casts string to BigDecimal for monetary fields" do
        submission[:total_amount] = "1234.56"
        expect(submission[:total_amount]).to be_a(BigDecimal)
        expect(submission[:total_amount]).to eq(BigDecimal("1234.56"))
      end

      it "preserves string for boolean fields" do
        submission[:is_agent] = "Oui"
        expect(submission[:is_agent]).to eq("Oui")
      end

      it "stores nil when value is nil" do
        submission[:total_clients] = 50
        submission[:total_clients] = nil
        expect(submission[:total_clients]).to be_nil
      end

      it "stores nil for empty string on integer fields" do
        submission[:total_clients] = ""
        expect(submission[:total_clients]).to be_nil
      end
    end

    context "case normalization" do
      it "normalizes field ID to lowercase" do
        submission[:TOTAL_CLIENTS] = 50
        expect(submission[:total_clients]).to eq(50)
      end

      it "normalizes mixed-case field ID" do
        submission[:Total_Clients] = 75
        expect(submission[:total_clients]).to eq(75)
      end

      it "accepts string keys and normalizes to lowercase symbols" do
        submission["TOTAL_CLIENTS"] = 100
        expect(submission[:total_clients]).to eq(100)
      end
    end

    context "unknown fields" do
      it "raises UnknownFieldError for unknown field" do
        expect {
          submission[:nonexistent_field] = 100
        }.to raise_error(AmsfSurvey::UnknownFieldError, "Unknown field: nonexistent_field")
      end

      it "includes field_id in the error" do
        begin
          submission[:unknown] = "value"
        rescue AmsfSurvey::UnknownFieldError => e
          expect(e.field_id).to eq(:unknown)
        end
      end
    end
  end

  describe "#[]" do
    let(:submission) do
      described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )
    end

    it "returns stored value" do
      submission[:total_clients] = 50
      expect(submission[:total_clients]).to eq(50)
    end

    it "returns nil for unset field" do
      expect(submission[:total_clients]).to be_nil
    end

    it "normalizes field ID to lowercase for lookup" do
      submission[:total_clients] = 50
      expect(submission[:TOTAL_CLIENTS]).to eq(50)
      expect(submission["Total_Clients"]).to eq(50)
    end

    it "raises UnknownFieldError for unknown field" do
      expect {
        submission[:nonexistent_field]
      }.to raise_error(AmsfSurvey::UnknownFieldError, "Unknown field: nonexistent_field")
    end
  end

  describe "#data" do
    it "returns the raw data hash with original XBRL ID keys" do
      submission = described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      submission[:total_clients] = 50
      submission[:is_agent] = "Oui"

      # Data is keyed by original XBRL IDs (which happen to be lowercase in this fixture)
      expect(submission.data).to eq({
        total_clients: 50,
        is_agent: "Oui"
      })
    end

    it "returns a frozen copy to prevent external mutation" do
      submission = described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      submission[:total_clients] = 50
      data = submission.data

      expect(data).to be_frozen
      expect { data[:total_clients] = 100 }.to raise_error(FrozenError)
    end

    it "does not affect internal state when external copy is obtained" do
      submission = described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      submission[:total_clients] = 50
      _data = submission.data

      # Internal state should be unchanged
      expect(submission[:total_clients]).to eq(50)
    end
  end

  describe "#complete?" do
    let(:submission) do
      described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )
    end

    context "with all visible fields filled" do
      it "returns true" do
        # Fill all visible fields
        # total_clients, total_amount, is_agent, computed_total are visible
        # agent_details depends on is_agent = "Oui"
        submission[:total_clients] = 50
        submission[:total_amount] = "1000.00"
        submission[:is_agent] = "Non"
        submission[:computed_total] = 100
        # agent_details is hidden because is_agent = "Non"

        expect(submission.complete?).to be true
      end
    end

    context "with missing fields" do
      it "returns false" do
        submission[:total_clients] = 50
        # total_amount, is_agent, computed_total are missing

        expect(submission.complete?).to be false
      end
    end

    context "with gate opening dependent fields" do
      it "requires dependent fields when gate is satisfied" do
        submission[:total_clients] = 50
        submission[:total_amount] = "1000.00"
        submission[:is_agent] = "Oui"
        submission[:computed_total] = 100
        # agent_details is now visible and required

        expect(submission.complete?).to be false
      end

      it "is complete when dependent fields are filled" do
        submission[:total_clients] = 50
        submission[:total_amount] = "1000.00"
        submission[:is_agent] = "Oui"
        submission[:agent_details] = "Agent info"
        submission[:computed_total] = 100

        expect(submission.complete?).to be true
      end
    end
  end

  describe "#missing_fields" do
    let(:submission) do
      described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )
    end

    it "returns all visible fields when empty" do
      # With is_agent not set, agent_details is hidden
      expect(submission.missing_fields).to contain_exactly(
        :total_clients, :total_amount, :is_agent, :computed_total
      )
    end

    it "excludes filled fields" do
      submission[:total_clients] = 50
      submission[:is_agent] = "Non"

      expect(submission.missing_fields).to contain_exactly(:total_amount, :computed_total)
    end

    it "excludes hidden fields when gate is not satisfied" do
      submission[:is_agent] = "Non"
      # agent_details is hidden, should not appear in missing

      expect(submission.missing_fields).not_to include(:agent_details)
    end

    it "includes dependent fields when gate is satisfied" do
      submission[:is_agent] = "Oui"
      # agent_details is now visible

      expect(submission.missing_fields).to include(:agent_details)
    end

    it "returns lowercase field IDs" do
      # All missing field IDs should be lowercase symbols
      submission.missing_fields.each do |field_id|
        expect(field_id).to eq(field_id.to_s.downcase.to_sym)
      end
    end
  end

  describe "#completion_percentage" do
    let(:submission) do
      described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )
    end

    it "returns 0.0 when no fields are filled" do
      expect(submission.completion_percentage).to eq(0.0)
    end

    it "returns 100.0 when all visible fields are filled" do
      submission[:total_clients] = 50
      submission[:total_amount] = "1000.00"
      submission[:is_agent] = "Non"
      submission[:computed_total] = 100

      expect(submission.completion_percentage).to eq(100.0)
    end

    it "returns percentage based on filled/visible ratio" do
      submission[:total_clients] = 50
      # 1 of 4 visible fields filled
      expect(submission.completion_percentage).to eq(25.0)
    end

    it "adjusts for gate-dependent fields" do
      submission[:is_agent] = "Oui"
      submission[:total_clients] = 50
      # Now 5 visible fields: total_clients, total_amount, is_agent, agent_details, computed_total
      # 2 filled: is_agent, total_clients
      expect(submission.completion_percentage).to eq(40.0)
    end
  end

  describe "#field_visible?" do
    let(:submission) do
      described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )
    end

    context "field with no dependencies" do
      it "returns true" do
        expect(submission.field_visible?(:total_clients)).to be true
      end
    end

    context "field with gate dependency" do
      it "returns false when gate is not satisfied" do
        submission[:is_agent] = "Non"
        expect(submission.field_visible?(:agent_details)).to be false
      end

      it "returns true when gate is satisfied" do
        submission[:is_agent] = "Oui"
        expect(submission.field_visible?(:agent_details)).to be true
      end

      it "returns false when gate is not answered" do
        expect(submission.field_visible?(:agent_details)).to be false
      end
    end

    context "case normalization" do
      it "accepts any casing for field ID" do
        expect(submission.field_visible?(:TOTAL_CLIENTS)).to be true
        expect(submission.field_visible?("Total_Clients")).to be true
      end
    end

    context "unknown field" do
      it "raises UnknownFieldError" do
        expect {
          submission.field_visible?(:nonexistent)
        }.to raise_error(AmsfSurvey::UnknownFieldError)
      end
    end
  end
end
