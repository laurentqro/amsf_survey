# frozen_string_literal: true

require "benchmark"

RSpec.describe "Real Estate Taxonomy Integration", :integration do
  # Path to the real_estate gem taxonomy
  let(:taxonomy_path) { File.expand_path("../../../amsf_survey-real_estate/taxonomies", __dir__) }

  before(:each) do
    AmsfSurvey.reset_registry!
    # Manually register since require only works once
    AmsfSurvey.register_plugin(
      industry: :real_estate,
      taxonomy_path: taxonomy_path
    )
  end

  describe "loading questionnaire" do
    subject(:questionnaire) { AmsfSurvey.questionnaire(industry: :real_estate, year: 2025) }

    it "loads successfully" do
      expect(questionnaire).to be_a(AmsfSurvey::Questionnaire)
    end

    it "has the correct industry and year" do
      expect(questionnaire.industry).to eq(:real_estate)
      expect(questionnaire.year).to eq(2025)
    end

    it "loads all sections from the taxonomy" do
      expect(questionnaire.section_count).to be > 0
    end

    it "loads all questions from the taxonomy" do
      expect(questionnaire.question_count).to be > 0
    end

    it "uses lowercase IDs for API access" do
      # Question IDs should be lowercase for consistent API usage
      questionnaire.questions.each do |question|
        expect(question.id.to_s).to eq(question.id.to_s.downcase)
      end
    end

    it "preserves original casing in xbrl_id for XBRL generation" do
      # Find a question with mixed case in XBRL
      aactive_question = questionnaire.question(:aactive)
      if aactive_question
        expect(aactive_question.xbrl_id).to eq(:aACTIVE)
      end
    end

    it "populates question labels from lab.xml" do
      # Find any question with a label
      question_with_label = questionnaire.questions.find { |q| q.label && !q.label.empty? }
      expect(question_with_label).not_to be_nil

      expect(question_with_label.label).to be_a(String)
      expect(question_with_label.label.length).to be > 0
      # Labels should have HTML stripped
      expect(question_with_label.label).not_to include("<p>")
      expect(question_with_label.label).not_to include("<b>")
    end

    it "identifies gate questions" do
      gate_questions = questionnaire.gate_questions
      expect(gate_questions).not_to be_empty
      # aACTIVE should be identified as a gate (accessible as :aactive)
      aactive = questionnaire.question(:aactive)
      expect(aactive&.gate?).to be true if aactive
    end

    it "supports question lookup by lowercase ID" do
      # Look up by lowercase question ID
      question_by_id = questionnaire.question(:aactive)
      expect(question_by_id).not_to be_nil
    end

    it "normalizes mixed-case lookups to lowercase" do
      # Should find question regardless of input casing
      question_mixed = questionnaire.question(:aACTIVE)
      question_lower = questionnaire.question(:aactive)
      question_upper = questionnaire.question(:AACTIVE)

      expect(question_mixed).to eq(question_lower)
      expect(question_upper).to eq(question_lower)
    end
  end

  describe "performance requirements" do
    it "loads questionnaire in under 2 seconds (T070)" do
      AmsfSurvey.reset_registry!
      AmsfSurvey.register_plugin(industry: :real_estate, taxonomy_path: taxonomy_path)

      load_time = Benchmark.realtime do
        AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)
      end

      expect(load_time).to be < 2.0
    end

    it "returns cached questionnaire in under 10ms (T071)" do
      # First load to populate cache
      AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

      cache_time = Benchmark.realtime do
        AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)
      end

      expect(cache_time).to be < 0.010 # 10ms
    end
  end

  describe "gate visibility" do
    subject(:questionnaire) { AmsfSurvey.questionnaire(industry: :real_estate, year: 2025) }

    it "hides dependent questions when gate is closed" do
      # Find a question that depends on aACTIVE (original XBRL casing in depends_on)
      dependent_question = questionnaire.questions.find { |q| q.depends_on[:aACTIVE] }
      skip("No question depends on aACTIVE") unless dependent_question

      # When gate is "Non" (French for No), dependent questions should be hidden
      # visible? uses data keyed by original XBRL IDs
      expect(dependent_question.visible?({ aACTIVE: "Non" })).to be false
    end

    it "shows dependent questions when gate is open" do
      dependent_question = questionnaire.questions.find { |q| q.depends_on[:aACTIVE] }
      skip("No question depends on aACTIVE") unless dependent_question

      # Taxonomy uses French "Oui"/"Non" - XULE's "Yes" is translated to schema values
      # visible? uses data keyed by original XBRL IDs
      expect(dependent_question.visible?({ aACTIVE: "Oui" })).to be true
    end
  end
end
