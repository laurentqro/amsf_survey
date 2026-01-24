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

    it "loads all fields from the taxonomy" do
      expect(questionnaire.field_count).to be > 0
    end

    it "uses lowercase IDs for API access" do
      # Field IDs should be lowercase for consistent API usage
      questionnaire.fields.each do |field|
        expect(field.id.to_s).to eq(field.id.to_s.downcase)
      end
    end

    it "preserves original casing in xbrl_id for XBRL generation" do
      # Find a field with mixed case in XBRL
      aactive_field = questionnaire.field(:aactive)
      if aactive_field
        expect(aactive_field.xbrl_id).to eq(:aACTIVE)
      end
    end

    it "populates field labels from lab.xml" do
      # Find any field with a label
      field_with_label = questionnaire.fields.find { |f| f.label && !f.label.empty? }
      expect(field_with_label).not_to be_nil

      expect(field_with_label.label).to be_a(String)
      expect(field_with_label.label.length).to be > 0
      # Labels should have HTML stripped
      expect(field_with_label.label).not_to include("<p>")
      expect(field_with_label.label).not_to include("<b>")
    end

    it "identifies gate fields" do
      gate_fields = questionnaire.gate_fields
      expect(gate_fields).not_to be_empty
      # aACTIVE should be identified as a gate (accessible as :aactive)
      aactive = questionnaire.field(:aactive)
      expect(aactive&.gate?).to be true if aactive
    end

    it "supports field lookup by lowercase ID" do
      # Look up by lowercase field ID
      field_by_id = questionnaire.field(:aactive)
      expect(field_by_id).not_to be_nil
    end

    it "normalizes mixed-case lookups to lowercase" do
      # Should find field regardless of input casing
      field_mixed = questionnaire.field(:aACTIVE)
      field_lower = questionnaire.field(:aactive)
      field_upper = questionnaire.field(:AACTIVE)

      expect(field_mixed).to eq(field_lower)
      expect(field_upper).to eq(field_lower)
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

    it "hides dependent fields when gate is closed" do
      # Find a field that depends on aactive (lowercase key in depends_on)
      dependent_field = questionnaire.fields.find { |f| f.depends_on[:aactive] }
      skip("No field depends on aactive") unless dependent_field

      # When gate is "Non" (French for No), dependent fields should be hidden
      expect(dependent_field.visible?({ aactive: "Non" })).to be false
    end

    it "shows dependent fields when gate is open" do
      dependent_field = questionnaire.fields.find { |f| f.depends_on[:aactive] }
      skip("No field depends on aactive") unless dependent_field

      # Taxonomy uses French "Oui"/"Non" - XULE's "Yes" is translated to schema values
      expect(dependent_field.visible?({ aactive: "Oui" })).to be true
    end
  end
end
