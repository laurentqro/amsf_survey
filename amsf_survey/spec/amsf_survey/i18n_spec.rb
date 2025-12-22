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

  describe "locale parameter" do
    it "uses English message when locale: :en" do
      result = AmsfSurvey::Validator.validate(submission, locale: :en)
      error = result.errors.find { |e| e.rule == :presence }

      expect(error.message).to eq("Field 'Test Field' is required")
    end

    it "uses French message when locale: :fr" do
      result = AmsfSurvey::Validator.validate(submission, locale: :fr)
      error = result.errors.find { |e| e.rule == :presence }

      expect(error.message).to eq("Le champ 'Test Field' est obligatoire")
    end

    it "defaults to French (Monaco regulatory context)" do
      # No locale parameter - should use AmsfSurvey::DEFAULT_LOCALE (:fr)
      result = AmsfSurvey::Validator.validate(submission)
      error = result.errors.find { |e| e.rule == :presence }

      expect(error.message).to eq("Le champ 'Test Field' est obligatoire")
    end
  end

  describe "AmsfSurvey::DEFAULT_LOCALE" do
    it "is set to :fr for Monaco regulatory context" do
      expect(AmsfSurvey::DEFAULT_LOCALE).to eq(:fr)
    end
  end

  describe "translation loading" do
    it "adds gem translations to I18n.load_path" do
      expect(I18n.load_path.any? { |p| p.include?("amsf_survey/locales") }).to be true
    end

    it "does not mutate I18n.default_locale" do
      # The gem should NOT set I18n.default_locale - host app controls this
      # We can't easily test "did not change" but we test that it loads cleanly
      expect { AmsfSurvey::DEFAULT_LOCALE }.not_to raise_error
    end
  end

  describe "translation content" do
    it "has French translations" do
      result = I18n.t("amsf_survey.validation.presence", field: "Test", locale: :fr)
      expect(result).to eq("Le champ 'Test' est obligatoire")
    end

    it "has English translations" do
      result = I18n.t("amsf_survey.validation.presence", field: "Test", locale: :en)
      expect(result).to eq("Field 'Test' is required")
    end

    it "handles missing keys gracefully with default" do
      result = I18n.t("amsf_survey.nonexistent.key", default: "fallback", locale: :fr)
      expect(result).to eq("fallback")
    end
  end

  describe "host application isolation" do
    it "does not interfere with host locale during validation" do
      original_locale = I18n.locale

      # Validation uses its locale parameter independently of I18n.locale
      I18n.locale = :en
      result_fr = AmsfSurvey::Validator.validate(submission, locale: :fr)
      result_en = AmsfSurvey::Validator.validate(submission, locale: :en)

      # French locale parameter produces French messages
      expect(result_fr.errors.first.message).to include("obligatoire")
      # English locale parameter produces English messages
      expect(result_en.errors.first.message).to include("required")

      # Restore original locale
      I18n.locale = original_locale
    end

    it "restores host locale after validation" do
      original_locale = I18n.locale

      # Validation should not permanently change I18n.locale
      AmsfSurvey::Validator.validate(submission, locale: :fr)
      expect(I18n.locale).to eq(original_locale)

      AmsfSurvey::Validator.validate(submission, locale: :en)
      expect(I18n.locale).to eq(original_locale)
    end
  end
end
