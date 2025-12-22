# frozen_string_literal: true

require "bigdecimal"

RSpec.describe AmsfSurvey::Submission do
  # Mock questionnaire and fields for testing
  let(:integer_field) do
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

  let(:monetary_field) do
    AmsfSurvey::Field.new(
      id: :total_amount,
      name: :total_amount,
      type: :monetary,
      xbrl_type: "xbrli:monetaryItemType",
      source_type: :prefillable,
      label: "Total Amount",
      section_id: :general,
      order: 2,
      gate: false
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
      order: 3,
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
      order: 4,
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
      order: 5,
      gate: false
    )
  end

  let(:section) do
    AmsfSurvey::Section.new(
      id: :general,
      name: "General Information",
      order: 1,
      fields: [integer_field, monetary_field, boolean_field, dependent_field, computed_field]
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

    it "raises UnknownFieldError for unknown field" do
      expect {
        submission[:nonexistent_field]
      }.to raise_error(AmsfSurvey::UnknownFieldError, "Unknown field: nonexistent_field")
    end
  end

  describe "#data" do
    it "returns the raw data hash" do
      submission = described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )

      submission[:total_clients] = 50
      submission[:is_agent] = "Oui"

      expect(submission.data).to eq({
        total_clients: 50,
        is_agent: "Oui"
      })
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

    context "with all required visible fields filled" do
      it "returns true" do
        # Fill all required non-computed visible fields
        # total_clients, total_amount, is_agent are required (non-computed)
        # agent_details depends on is_agent = "Oui"
        submission[:total_clients] = 50
        submission[:total_amount] = "1000.00"
        submission[:is_agent] = "Non"
        # computed_total is computed, not required
        # agent_details is hidden because is_agent = "Non"

        expect(submission.complete?).to be true
      end
    end

    context "with missing required fields" do
      it "returns false" do
        submission[:total_clients] = 50
        # total_amount and is_agent are missing

        expect(submission.complete?).to be false
      end
    end

    context "with gate opening dependent fields" do
      it "requires dependent fields when gate is satisfied" do
        submission[:total_clients] = 50
        submission[:total_amount] = "1000.00"
        submission[:is_agent] = "Oui"
        # agent_details is now visible and required

        expect(submission.complete?).to be false
      end

      it "is complete when dependent fields are filled" do
        submission[:total_clients] = 50
        submission[:total_amount] = "1000.00"
        submission[:is_agent] = "Oui"
        submission[:agent_details] = "Agent info"

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

    it "returns all required visible fields when empty" do
      # With is_agent not set, agent_details is hidden
      expect(submission.missing_fields).to contain_exactly(:total_clients, :total_amount, :is_agent)
    end

    it "excludes filled fields" do
      submission[:total_clients] = 50
      submission[:is_agent] = "Non"

      expect(submission.missing_fields).to contain_exactly(:total_amount)
    end

    it "excludes hidden fields when gate is not satisfied" do
      submission[:is_agent] = "Non"
      # agent_details is hidden, should not appear in missing

      expect(submission.missing_fields).not_to include(:agent_details)
    end

    it "includes dependent fields when gate is satisfied" do
      submission[:is_agent] = "Oui"
      # agent_details is now visible and required

      expect(submission.missing_fields).to include(:agent_details)
    end

    it "excludes computed fields" do
      # computed_total should never appear in missing_fields
      expect(submission.missing_fields).not_to include(:computed_total)
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

    it "returns 100.0 when all required fields are filled" do
      submission[:total_clients] = 50
      submission[:total_amount] = "1000.00"
      submission[:is_agent] = "Non"

      expect(submission.completion_percentage).to eq(100.0)
    end

    it "returns percentage based on filled/required ratio" do
      submission[:total_clients] = 50
      # 1 of 3 required fields filled
      expect(submission.completion_percentage).to be_within(0.1).of(33.3)
    end

    it "adjusts for gate-dependent fields" do
      submission[:is_agent] = "Oui"
      submission[:total_clients] = 50
      # Now 4 required fields: total_clients, total_amount, is_agent, agent_details
      # 2 filled: is_agent, total_clients
      expect(submission.completion_percentage).to eq(50.0)
    end
  end

  describe "#missing_entry_only_fields" do
    let(:submission) do
      described_class.new(
        industry: :real_estate,
        year: 2025,
        entity_id: "ENTITY_001",
        period: Date.new(2025, 12, 31)
      )
    end

    it "returns only entry_only fields that are missing" do
      # total_clients and is_agent are entry_only
      # total_amount is prefillable
      expect(submission.missing_entry_only_fields).to contain_exactly(:total_clients, :is_agent)
    end

    it "excludes prefillable fields" do
      # total_amount is prefillable, should not appear
      expect(submission.missing_entry_only_fields).not_to include(:total_amount)
    end

    it "excludes filled entry_only fields" do
      submission[:total_clients] = 50
      expect(submission.missing_entry_only_fields).not_to include(:total_clients)
    end

    it "respects gate visibility" do
      submission[:is_agent] = "Oui"
      # agent_details is entry_only and now visible
      expect(submission.missing_entry_only_fields).to include(:agent_details)
    end
  end
end
