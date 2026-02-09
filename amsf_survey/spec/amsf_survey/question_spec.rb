# frozen_string_literal: true

RSpec.describe AmsfSurvey::Question do
  let(:field) do
    AmsfSurvey::Field.new(
      id: :aACTIVE,
      type: :boolean,
      xbrl_type: "test:booleanItemType",
      label: { fr: "Êtes-vous actif?", en: "Are you active?" },
      gate: true,
      verbose_label: { fr: "Libellé détaillé", en: "Extended label" },
      valid_values: %w[Oui Non],
      depends_on: {}
    )
  end

  describe "#initialize" do
    it "creates a question with number, instructions, and field" do
      question = described_class.new(number: 1, field: field, instructions: "Help text")

      expect(question.number).to eq(1)
      expect(question.instructions).to eq("Help text")
    end

    it "allows nil instructions" do
      question = described_class.new(number: 1, field: field, instructions: nil)

      expect(question.instructions).to be_nil
    end
  end

  describe "delegation to field" do
    subject(:question) { described_class.new(number: 1, field: field, instructions: nil) }

    it "delegates id to field" do
      expect(question.id).to eq(:aactive)
    end

    it "delegates xbrl_id to field" do
      expect(question.xbrl_id).to eq(:aACTIVE)
    end

    it "delegates label to field with default locale" do
      expect(question.label).to eq("Êtes-vous actif?")
    end

    it "delegates label to field with explicit locale" do
      expect(question.label(:en)).to eq("Are you active?")
    end

    it "delegates verbose_label to field" do
      expect(question.verbose_label).to eq("Libellé détaillé")
      expect(question.verbose_label(:en)).to eq("Extended label")
    end

    it "delegates type to field" do
      expect(question.type).to eq(:boolean)
    end

    it "delegates valid_values to field" do
      expect(question.valid_values).to eq(%w[Oui Non])
    end

    it "delegates gate? to field" do
      expect(question.gate?).to be true
    end

    it "delegates depends_on to field" do
      expect(question.depends_on).to eq({})
    end
  end

  describe "#instructions (locale-aware)" do
    it "returns instructions as plain string (backward compatibility)" do
      question = described_class.new(number: 1, field: field, instructions: "Help text")
      expect(question.instructions).to eq("Help text")
    end

    it "returns instructions from locale hash" do
      question = described_class.new(number: 1, field: field,
        instructions: { fr: "Aide", en: "Help" })
      expect(question.instructions(:fr)).to eq("Aide")
      expect(question.instructions(:en)).to eq("Help")
    end

    it "falls back to :fr when locale missing" do
      question = described_class.new(number: 1, field: field,
        instructions: { fr: "Aide" })
      expect(question.instructions(:en)).to eq("Aide")
    end
  end

  describe "#visible?" do
    let(:gated_field) do
      AmsfSurvey::Field.new(
        id: :t001,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        label: "Count",
          gate: false,
        depends_on: { tGATE: "Oui" }
      )
    end

    subject(:question) { described_class.new(number: 1, field: gated_field, instructions: nil) }

    it "returns true when dependencies are satisfied" do
      expect(question.visible?({ tGATE: "Oui" })).to be true
    end

    it "returns false when dependencies are not satisfied" do
      expect(question.visible?({ tGATE: "Non" })).to be false
    end
  end
end
