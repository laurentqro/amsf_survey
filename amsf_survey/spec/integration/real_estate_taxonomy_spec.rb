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

    it "applies semantic mappings" do
      # Check that mapped fields have semantic names
      has_activity_field = questionnaire.field(:has_activity)
      expect(has_activity_field).not_to be_nil
      expect(has_activity_field.name).to eq(:has_activity)
    end

    it "uses XBRL code for unmapped fields" do
      # Fields not in semantic_mappings.yml should use their XBRL code
      fields_with_xbrl_names = questionnaire.fields.select { |f| f.name.to_s.start_with?("a") }
      expect(fields_with_xbrl_names).not_to be_empty
    end

    it "populates field labels from lab.xml" do
      field = questionnaire.field(:total_clients)
      skip("total_clients not mapped") unless field

      expect(field.label).to be_a(String)
      expect(field.label.length).to be > 0
      # Labels should have HTML stripped
      expect(field.label).not_to include("<p>")
      expect(field.label).not_to include("<b>")
    end

    it "identifies gate fields" do
      gate_fields = questionnaire.gate_fields
      expect(gate_fields).not_to be_empty
      # aACTIVE should be identified as a gate
      has_activity = questionnaire.field(:has_activity)
      expect(has_activity&.gate?).to be true if has_activity
    end

    it "supports field lookup by ID" do
      # Look up by semantic name
      field_by_name = questionnaire.field(:has_activity)
      expect(field_by_name).not_to be_nil
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
      # Find a field that depends on aACTIVE
      dependent_field = questionnaire.fields.find { |f| f.depends_on[:aACTIVE] }
      skip("No field depends on aACTIVE") unless dependent_field

      # When gate is "Non" (French for No), dependent fields should be hidden
      expect(dependent_field.visible?({ aACTIVE: "Non" })).to be false
    end

    it "shows dependent fields when gate is open" do
      dependent_field = questionnaire.fields.find { |f| f.depends_on[:aACTIVE] }
      skip("No field depends on aACTIVE") unless dependent_field

      # Taxonomy uses French "Oui"/"Non" - XULE's "Yes" is translated to schema values
      expect(dependent_field.visible?({ aACTIVE: "Oui" })).to be true
    end
  end
end
