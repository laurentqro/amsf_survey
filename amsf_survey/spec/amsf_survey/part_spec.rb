# frozen_string_literal: true

RSpec.describe AmsfSurvey::Part do
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
    AmsfSurvey::Subsection.new(number: "1.1", title: "Sub 1", questions: questions)
  end

  let(:section) do
    AmsfSurvey::Section.new(number: 1, title: "Customer Risk", subsections: [subsection])
  end

  describe "#initialize" do
    it "creates a part with name and sections" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.name).to eq("Inherent Risk")
      expect(part.sections).to eq([section])
    end
  end

  describe "#questions" do
    it "returns all questions from all sections" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.questions).to eq(questions)
    end
  end

  describe "#question_count" do
    it "returns total number of questions" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.question_count).to eq(2)
    end
  end

  describe "#section_count" do
    it "returns number of sections" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.section_count).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns false when part has sections" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.empty?).to be false
    end

    it "returns true when part has no sections" do
      part = described_class.new(name: "Empty", sections: [])

      expect(part.empty?).to be true
    end
  end
end
