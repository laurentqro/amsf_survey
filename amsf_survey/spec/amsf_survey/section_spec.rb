# frozen_string_literal: true

RSpec.describe AmsfSurvey::Section do
  let(:field1) do
    AmsfSurvey::Field.new(
      id: :t001,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      label: "Total clients",
      section_id: :general,
      order: 1,
      gate: false,
      depends_on: {}
    )
  end

  let(:field2) do
    AmsfSurvey::Field.new(
      id: :t002,
      type: :string,
      xbrl_type: "xbrli:stringItemType",
      label: "Comments",
      section_id: :general,
      order: 2,
      gate: false,
      depends_on: { tGATE: "Oui" }  # Original XBRL casing in depends_on
    )
  end

  let(:section) do
    described_class.new(
      id: :general,
      name: "Link_General",
      order: 1,
      fields: [field1, field2]
    )
  end

  describe "#initialize" do
    it "creates a section with required attributes" do
      expect(section.id).to eq(:general)
      expect(section.name).to eq("Link_General")
      expect(section.order).to eq(1)
      expect(section.fields).to eq([field1, field2])
    end

    it "allows empty fields array" do
      empty_section = described_class.new(
        id: :empty,
        name: "Empty Section",
        order: 1,
        fields: []
      )
      expect(empty_section.fields).to eq([])
    end
  end

  describe "#field_count" do
    it "returns the number of fields" do
      expect(section.field_count).to eq(2)
    end

    it "returns 0 for empty section" do
      empty_section = described_class.new(id: :empty, name: "Empty", order: 1, fields: [])
      expect(empty_section.field_count).to eq(0)
    end
  end

  describe "#empty?" do
    it "returns false when section has fields" do
      expect(section.empty?).to be false
    end

    it "returns true when section has no fields" do
      empty_section = described_class.new(id: :empty, name: "Empty", order: 1, fields: [])
      expect(empty_section.empty?).to be true
    end
  end

  describe "#visible? (private, tested via send)" do
    context "when any field is visible" do
      it "returns true" do
        # field1 has no dependencies, so it's always visible
        expect(section.send(:visible?, { tGATE: "Non" })).to be true
      end
    end

    context "when all fields are hidden" do
      let(:gated_field1) do
        AmsfSurvey::Field.new(
          id: :g1,
          type: :integer,
          xbrl_type: "xbrli:integerItemType",
          label: "Gated 1",
          section_id: :gated,
          order: 1,
          gate: false,
          depends_on: { tGATE: "Oui" }  # Original XBRL casing
        )
      end

      let(:gated_field2) do
        AmsfSurvey::Field.new(
          id: :g2,
          type: :integer,
          xbrl_type: "xbrli:integerItemType",
          label: "Gated 2",
          section_id: :gated,
          order: 2,
          gate: false,
          depends_on: { tGATE: "Oui" }  # Original XBRL casing
        )
      end

      let(:gated_section) do
        described_class.new(
          id: :gated,
          name: "Gated Section",
          order: 1,
          fields: [gated_field1, gated_field2]
        )
      end

      it "returns false when gate is closed" do
        expect(gated_section.send(:visible?, { tGATE: "Non" })).to be false
      end

      it "returns true when gate is open" do
        expect(gated_section.send(:visible?, { tGATE: "Oui" })).to be true
      end
    end

    context "with empty section" do
      it "returns false" do
        empty_section = described_class.new(id: :empty, name: "Empty", order: 1, fields: [])
        expect(empty_section.send(:visible?, {})).to be false
      end
    end
  end
end
