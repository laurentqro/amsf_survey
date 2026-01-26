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
end
