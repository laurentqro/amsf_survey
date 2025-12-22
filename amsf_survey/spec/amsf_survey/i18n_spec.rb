# frozen_string_literal: true

RSpec.describe "I18n validation messages" do
  let(:field) do
    AmsfSurvey::Field.new(
      id: :test_field,
      name: :test_field,
      type: :integer,
      xbrl_type: "xbrli:integerItemType",
      source_type: :entry_only,
      label: "Test Field",
      section_id: :general,
      order: 1,
      gate: false
    )
  end

  let(:section) do
    AmsfSurvey::Section.new(
      id: :general,
      name: "General",
      order: 1,
      fields: [field]
    )
  end

  let(:questionnaire) do
    AmsfSurvey::Questionnaire.new(
      industry: :test,
      year: 2025,
      sections: [section]
    )
  end

  let(:submission) do
    sub = AmsfSurvey::Submission.new(
      industry: :test,
      year: 2025,
      entity_id: "TEST",
      period: Date.new(2025, 12, 31)
    )
    allow(sub).to receive(:questionnaire).and_return(questionnaire)
    sub
  end

  describe "presence validation messages" do
    it "uses English message when locale is :en" do
      I18n.with_locale(:en) do
        result = AmsfSurvey::Validator.validate(submission)
        error = result.errors.find { |e| e.rule == :presence }

        expect(error.message).to eq("Field 'Test Field' is required")
      end
    end

    it "uses French message when locale is :fr" do
      I18n.with_locale(:fr) do
        result = AmsfSurvey::Validator.validate(submission)
        error = result.errors.find { |e| e.rule == :presence }

        expect(error.message).to eq("Le champ 'Test Field' est obligatoire")
      end
    end
  end

  describe "default locale" do
    it "defaults to French for Monaco regulatory context" do
      expect(I18n.default_locale).to eq(:fr)
    end
  end
end
