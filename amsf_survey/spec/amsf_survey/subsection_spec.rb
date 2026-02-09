# frozen_string_literal: true

RSpec.describe AmsfSurvey::Subsection do
  let(:field1) do
    AmsfSurvey::Field.new(
      id: :t001, type: :integer, xbrl_type: "xbrli:integerItemType",
      label: "Field 1", gate: false
    )
  end

  let(:field2) do
    AmsfSurvey::Field.new(
      id: :t002, type: :string, xbrl_type: "xbrli:stringItemType",
      label: "Field 2", gate: false
    )
  end

  let(:questions) do
    [
      AmsfSurvey::Question.new(number: 1, field: field1, instructions: "Help 1"),
      AmsfSurvey::Question.new(number: 2, field: field2, instructions: nil)
    ]
  end

  describe "#initialize" do
    it "creates a subsection with number, title, and questions" do
      subsection = described_class.new(
        number: 1,
        title: "Soumis à la loi",
        questions: questions
      )

      expect(subsection.number).to eq(1)
      expect(subsection.title).to eq("Soumis à la loi")
      expect(subsection.questions).to eq(questions)
    end
  end

  describe "#title (locale-aware)" do
    it "accepts a plain string" do
      subsection = described_class.new(number: 1, title: "Activity Status", questions: [])
      expect(subsection.title).to eq("Activity Status")
    end

    it "accepts a locale hash" do
      subsection = described_class.new(
        number: 1,
        title: { fr: "Statut d'activité", en: "Activity Status" },
        questions: []
      )
      expect(subsection.title(:fr)).to eq("Statut d'activité")
      expect(subsection.title(:en)).to eq("Activity Status")
    end
  end

  describe "#instructions (locale-aware)" do
    it "returns nil when no instructions" do
      subsection = described_class.new(number: 1, title: "Test", questions: [])
      expect(subsection.instructions).to be_nil
    end

    it "accepts a plain string" do
      subsection = described_class.new(
        number: 1, title: "Test", questions: [],
        instructions: "Report only relevant info."
      )
      expect(subsection.instructions).to eq("Report only relevant info.")
    end

    it "accepts a locale hash" do
      subsection = described_class.new(
        number: 1, title: "Test", questions: [],
        instructions: { fr: "Instructions FR", en: "Instructions EN" }
      )
      expect(subsection.instructions(:fr)).to eq("Instructions FR")
      expect(subsection.instructions(:en)).to eq("Instructions EN")
    end
  end

  describe "#question_count" do
    it "returns the number of questions" do
      subsection = described_class.new(number: 1, title: "Test", questions: questions)
      expect(subsection.question_count).to eq(2)
    end
  end

  describe "#empty?" do
    it "returns false when subsection has questions" do
      subsection = described_class.new(number: 1, title: "Test", questions: questions)
      expect(subsection.empty?).to be false
    end

    it "returns true when subsection has no questions" do
      subsection = described_class.new(number: 1, title: "Test", questions: [])
      expect(subsection.empty?).to be true
    end
  end

  describe "#number" do
    it "accepts string numbers like '1.1'" do
      subsection = described_class.new(number: "1.1", title: "Test", questions: [])
      expect(subsection.number).to eq("1.1")
    end

    it "accepts integer numbers" do
      subsection = described_class.new(number: 1, title: "Test", questions: [])
      expect(subsection.number).to eq(1)
    end
  end
end
