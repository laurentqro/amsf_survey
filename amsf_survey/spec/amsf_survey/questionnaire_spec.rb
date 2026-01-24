# frozen_string_literal: true

RSpec.describe AmsfSurvey::Questionnaire do
  let(:gate_field) do
    AmsfSurvey::Field.new(
      id: :tGATE,
      type: :boolean,
      xbrl_type: "xbrli:stringItemType",
      label: "Did you perform activities?",
      section_id: :general,
      order: 1,
      gate: true,
      valid_values: %w[Oui Non],
      depends_on: {}
    )
  end

  let(:integer_field) do
    AmsfSurvey::Field.new(
      id: :t001,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      label: "Total clients",
      section_id: :general,
      order: 2,
      gate: false,
      depends_on: { tGATE: "Oui" }  # Original XBRL casing in depends_on
    )
  end

  let(:string_field) do
    AmsfSurvey::Field.new(
      id: :t002,
      type: :string,
      xbrl_type: "xbrli:stringItemType",
      label: "Comments",
      section_id: :general,
      order: 3,
      gate: false,
      depends_on: {}
    )
  end

  let(:monetary_field) do
    AmsfSurvey::Field.new(
      id: :t003,
      type: :monetary,
      xbrl_type: "xbrli:monetaryItemType",
      label: "Total amount",
      section_id: :details,
      order: 1,
      gate: false,
      depends_on: { tGATE: "Oui" }  # Original XBRL casing in depends_on
    )
  end

  let(:enum_field) do
    AmsfSurvey::Field.new(
      id: :t004,
      type: :enum,
      xbrl_type: "xbrli:stringItemType",
      label: "Service type",
      section_id: :details,
      order: 2,
      gate: false,
      valid_values: ["Option A", "Option B", "Option C"],
      depends_on: {}
    )
  end

  let(:section1) do
    AmsfSurvey::Section.new(
      id: :general,
      name: "Link_General",
      order: 1,
      fields: [gate_field, integer_field, string_field]
    )
  end

  let(:section2) do
    AmsfSurvey::Section.new(
      id: :details,
      name: "Link_Details",
      order: 2,
      fields: [monetary_field, enum_field]
    )
  end

  let(:questionnaire) do
    described_class.new(
      industry: :test_industry,
      year: 2025,
      sections: [section1, section2]
    )
  end

  describe "#initialize" do
    it "creates a questionnaire with required attributes" do
      expect(questionnaire.industry).to eq(:test_industry)
      expect(questionnaire.year).to eq(2025)
      expect(questionnaire.sections).to eq([section1, section2])
    end

    it "accepts optional taxonomy_namespace" do
      q = described_class.new(
        industry: :test_industry,
        year: 2025,
        sections: [section1],
        taxonomy_namespace: "https://example.com/taxonomy/2025"
      )
      expect(q.taxonomy_namespace).to eq("https://example.com/taxonomy/2025")
    end

    it "defaults taxonomy_namespace to nil when not provided" do
      expect(questionnaire.taxonomy_namespace).to be_nil
    end
  end

  describe "#fields" do
    it "returns all fields across all sections" do
      expect(questionnaire.fields).to eq([gate_field, integer_field, string_field, monetary_field, enum_field])
    end

    it "returns fields in section order then field order" do
      ids = questionnaire.fields.map(&:id)
      expect(ids).to eq(%i[tgate t001 t002 t003 t004])
    end
  end

  describe "#field" do
    it "finds field by lowercase ID" do
      expect(questionnaire.field(:t001)).to eq(integer_field)
      expect(questionnaire.field(:t003)).to eq(monetary_field)
    end

    it "normalizes mixed-case input to lowercase" do
      expect(questionnaire.field(:T001)).to eq(integer_field)
      expect(questionnaire.field(:tGATE)).to eq(gate_field)
      expect(questionnaire.field("T003")).to eq(monetary_field)
    end

    it "returns nil for unknown field" do
      expect(questionnaire.field(:unknown)).to be_nil
    end

    it "finds fields by lowercase ID regardless of original casing" do
      expect(questionnaire.field(:tgate)).to eq(gate_field)
      expect(questionnaire.field(:t002)).to eq(string_field)
    end
  end

  describe "#field_count" do
    it "returns total number of fields" do
      expect(questionnaire.field_count).to eq(5)
    end
  end

  describe "#section_count" do
    it "returns number of sections" do
      expect(questionnaire.section_count).to eq(2)
    end
  end

  describe "#gate_fields" do
    it "returns fields where gate is true" do
      expect(questionnaire.gate_fields).to eq([gate_field])
    end
  end
end
