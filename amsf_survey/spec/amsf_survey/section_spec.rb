# frozen_string_literal: true

RSpec.describe AmsfSurvey::Section do
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
      AmsfSurvey::Question.new(number: 1, field: field1, instructions: nil),
      AmsfSurvey::Question.new(number: 2, field: field2, instructions: nil)
    ]
  end

  let(:subsection) do
    AmsfSurvey::Subsection.new(number: 1, title: "Sub 1", questions: questions)
  end

  describe "#initialize" do
    it "creates a section with number, title, and subsections" do
      section = described_class.new(
        number: 1,
        title: "Inherent Risk",
        subsections: [subsection]
      )

      expect(section.number).to eq(1)
      expect(section.title).to eq("Inherent Risk")
      expect(section.subsections).to eq([subsection])
    end
  end

  describe "#questions" do
    it "returns all questions from all subsections" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection]
      )

      expect(section.questions).to eq(questions)
    end

    it "returns questions in order across multiple subsections" do
      field3 = AmsfSurvey::Field.new(
        id: :t003, type: :boolean, xbrl_type: "xbrli:booleanItemType",
        label: "Field 3", gate: false
      )
      q3 = AmsfSurvey::Question.new(number: 3, field: field3, instructions: nil)
      subsection2 = AmsfSurvey::Subsection.new(number: 2, title: "Sub 2", questions: [q3])

      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection, subsection2]
      )

      expect(section.questions.map(&:number)).to eq([1, 2, 3])
    end
  end

  describe "#question_count" do
    it "returns total questions across all subsections" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection]
      )

      expect(section.question_count).to eq(2)
    end
  end

  describe "#subsection_count" do
    it "returns the number of subsections" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection]
      )

      expect(section.subsection_count).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns false when section has subsections with questions" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection]
      )

      expect(section.empty?).to be false
    end

    it "returns true when section has no subsections" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: []
      )

      expect(section.empty?).to be true
    end
  end
end
