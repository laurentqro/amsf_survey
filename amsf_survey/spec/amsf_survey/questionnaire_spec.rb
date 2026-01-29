# frozen_string_literal: true

RSpec.describe AmsfSurvey::Questionnaire do
  let(:gate_field) do
    AmsfSurvey::Field.new(
      id: :tGATE,
      type: :boolean,
      xbrl_type: "xbrli:stringItemType",
      label: "Did you perform activities?",
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
      gate: false,
      valid_values: ["Option A", "Option B", "Option C"],
      depends_on: {}
    )
  end

  # Questions wrap fields with PDF-sourced metadata
  let(:q1) { AmsfSurvey::Question.new(number: 1, field: gate_field, instructions: nil) }
  let(:q2) { AmsfSurvey::Question.new(number: 2, field: integer_field, instructions: nil) }
  let(:q3) { AmsfSurvey::Question.new(number: 3, field: string_field, instructions: nil) }
  let(:q4) { AmsfSurvey::Question.new(number: 1, field: monetary_field, instructions: nil) }
  let(:q5) { AmsfSurvey::Question.new(number: 2, field: enum_field, instructions: nil) }

  # Subsections group questions
  let(:subsection1) { AmsfSurvey::Subsection.new(number: 1, title: "Activity", questions: [q1, q2, q3]) }
  let(:subsection2) { AmsfSurvey::Subsection.new(number: 1, title: "Financial", questions: [q4, q5]) }

  # Sections contain subsections
  let(:section1) { AmsfSurvey::Section.new(number: 1, title: "General", subsections: [subsection1]) }
  let(:section2) { AmsfSurvey::Section.new(number: 2, title: "Details", subsections: [subsection2]) }

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

  describe "#questions" do
    it "returns all questions from all sections" do
      expect(questionnaire.questions).to eq([q1, q2, q3, q4, q5])
    end

    it "returns questions in section order" do
      numbers = questionnaire.questions.map(&:number)
      expect(numbers).to eq([1, 2, 3, 1, 2])  # Section 1: 1,2,3; Section 2: 1,2
    end
  end

  describe "#question_count" do
    it "returns total number of questions" do
      expect(questionnaire.question_count).to eq(5)
    end
  end

  describe "#question" do
    it "finds question by lowercase ID" do
      expect(questionnaire.question(:t001)).to eq(q2)
      expect(questionnaire.question(:t003)).to eq(q4)
    end

    it "normalizes mixed-case input to lowercase" do
      expect(questionnaire.question(:T001)).to eq(q2)
      expect(questionnaire.question(:tGATE)).to eq(q1)
      expect(questionnaire.question("T003")).to eq(q4)
    end

    it "returns nil for unknown question" do
      expect(questionnaire.question(:unknown)).to be_nil
    end

    it "finds questions by lowercase ID regardless of original casing" do
      expect(questionnaire.question(:tgate)).to eq(q1)
      expect(questionnaire.question(:t002)).to eq(q3)
    end
  end

  describe "#section_count" do
    it "returns number of sections" do
      expect(questionnaire.section_count).to eq(2)
    end
  end

  describe "#gate_questions" do
    it "returns questions where gate is true" do
      expect(questionnaire.gate_questions).to eq([q1])
    end
  end
end
