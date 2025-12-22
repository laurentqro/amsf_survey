# frozen_string_literal: true

RSpec.describe AmsfSurvey::Taxonomy::Loader do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }

  describe "#load" do
    subject(:questionnaire) { described_class.new(fixtures_path).load(:test_industry, 2025) }

    it "returns a Questionnaire object" do
      expect(questionnaire).to be_a(AmsfSurvey::Questionnaire)
    end

    it "sets industry and year" do
      expect(questionnaire.industry).to eq(:test_industry)
      expect(questionnaire.year).to eq(2025)
    end

    it "extracts taxonomy_namespace from XSD" do
      expect(questionnaire.taxonomy_namespace).to eq("https://test.example.com/test_industry_2025")
    end

    describe "sections" do
      it "creates sections from presentation file" do
        expect(questionnaire.sections.length).to eq(2)
      end

      it "orders sections correctly" do
        section_names = questionnaire.sections.map(&:name)
        expect(section_names).to eq(%w[Link_General Link_Details])
      end
    end

    describe "fields" do
      it "creates all 5 fields" do
        expect(questionnaire.field_count).to eq(5)
      end

      it "assigns correct types" do
        expect(questionnaire.field(:tGATE).type).to eq(:boolean)
        expect(questionnaire.field(:t001).type).to eq(:integer)
        expect(questionnaire.field(:t002).type).to eq(:string)
        expect(questionnaire.field(:t003).type).to eq(:monetary)
        expect(questionnaire.field(:t004).type).to eq(:enum)
      end

      it "preserves XBRL types" do
        expect(questionnaire.field(:t001).xbrl_type).to eq("xbrli:integerItemType")
      end
    end

    describe "semantic mappings" do
      it "applies semantic names from mappings" do
        expect(questionnaire.field(:total_clients)).not_to be_nil
        expect(questionnaire.field(:total_clients).id).to eq(:t001)
      end

      it "applies source_type from mappings" do
        expect(questionnaire.field(:total_clients).source_type).to eq(:computed)
        expect(questionnaire.field(:total_amount).source_type).to eq(:prefillable)
        expect(questionnaire.field(:performed_activities).source_type).to eq(:entry_only)
      end

      it "uses XBRL code as name for unmapped fields" do
        unmapped = questionnaire.field(:t002)
        expect(unmapped.name).to eq(:t002)
        expect(unmapped.id).to eq(:t002)
      end

      it "defaults to entry_only for unmapped fields" do
        unmapped = questionnaire.field(:t002)
        expect(unmapped.source_type).to eq(:entry_only)
      end
    end

    describe "labels" do
      it "strips HTML from labels" do
        field = questionnaire.field(:tGATE)
        expect(field.label).to eq("Avez-vous effectue des activites?")
      end

      it "includes verbose labels when present" do
        field = questionnaire.field(:tGATE)
        expect(field.verbose_label).to include("Si non, veuillez expliquer pourquoi")
      end
    end

    describe "gate dependencies" do
      it "marks gate fields" do
        gate = questionnaire.field(:tGATE)
        expect(gate.gate?).to be true
      end

      it "sets depends_on for controlled fields with translated values" do
        controlled = questionnaire.field(:t001)
        # XULE uses "Yes" but it gets translated to the schema's actual value ("Oui")
        expect(controlled.depends_on).to eq({ tGATE: "Oui" })
      end

      it "leaves non-gated fields without dependencies" do
        independent = questionnaire.field(:t002)
        expect(independent.depends_on).to eq({})
      end
    end

    describe "gate value translation" do
      let(:loader) { described_class.new(fixtures_path) }
      let(:schema_data) do
        {
          gate_field: { valid_values: %w[Oui Non] },
          english_gate: { valid_values: %w[Yes No] },
          no_values: {},
          many_values: { valid_values: %w[A B C] }
        }
      end

      it "translates XULE 'Yes' to French 'Oui'" do
        result = loader.send(:resolve_gate_dependencies, { gate_field: "Yes" }, schema_data)
        expect(result).to eq({ gate_field: "Oui" })
      end

      it "translates XULE 'No' to French 'Non'" do
        result = loader.send(:resolve_gate_dependencies, { gate_field: "No" }, schema_data)
        expect(result).to eq({ gate_field: "Non" })
      end

      it "preserves English 'Yes' when schema uses English" do
        result = loader.send(:resolve_gate_dependencies, { english_gate: "Yes" }, schema_data)
        expect(result).to eq({ english_gate: "Yes" })
      end

      it "preserves English 'No' when schema uses English" do
        result = loader.send(:resolve_gate_dependencies, { english_gate: "No" }, schema_data)
        expect(result).to eq({ english_gate: "No" })
      end

      it "returns original value when schema has no valid_values" do
        result = loader.send(:resolve_gate_dependencies, { no_values: "Yes" }, schema_data)
        expect(result).to eq({ no_values: "Yes" })
      end

      it "returns original value when valid_values has more than 2 options" do
        result = loader.send(:resolve_gate_dependencies, { many_values: "Yes" }, schema_data)
        expect(result).to eq({ many_values: "Yes" })
      end

      it "returns empty hash for nil dependencies" do
        result = loader.send(:resolve_gate_dependencies, nil, schema_data)
        expect(result).to eq({})
      end

      it "returns empty hash for empty dependencies" do
        result = loader.send(:resolve_gate_dependencies, {}, schema_data)
        expect(result).to eq({})
      end
    end

    describe "valid_values" do
      it "sets valid_values for boolean fields" do
        field = questionnaire.field(:tGATE)
        expect(field.valid_values).to eq(%w[Oui Non])
      end

      it "sets valid_values for enum fields" do
        field = questionnaire.field(:t004)
        expect(field.valid_values).to eq(["Option A", "Option B", "Option C"])
      end

      it "leaves valid_values nil for other types" do
        field = questionnaire.field(:t001)
        expect(field.valid_values).to be_nil
      end
    end
  end

  describe "error handling" do
    it "raises MissingSemanticMappingError when mappings file is missing" do
      # Use a path without semantic_mappings.yml
      temp_path = File.join(fixtures_path, "..", "no_mappings")
      FileUtils.mkdir_p(temp_path)
      FileUtils.cp(File.join(fixtures_path, "test_survey.xsd"), temp_path)

      loader = described_class.new(temp_path)
      expect { loader.load(:test, 2025) }.to raise_error(AmsfSurvey::MissingSemanticMappingError)
    ensure
      FileUtils.rm_rf(temp_path)
    end
  end

  describe "multiple file handling" do
    it "warns when multiple XSD files are found" do
      temp_path = File.join(fixtures_path, "..", "multi_xsd")
      FileUtils.mkdir_p(temp_path)
      FileUtils.cp(File.join(fixtures_path, "test_survey.xsd"), temp_path)
      FileUtils.cp(File.join(fixtures_path, "test_survey.xsd"), File.join(temp_path, "extra.xsd"))
      FileUtils.cp(File.join(fixtures_path, "semantic_mappings.yml"), temp_path)
      FileUtils.cp(File.join(fixtures_path, "test_survey_pre.xml"), temp_path)

      loader = described_class.new(temp_path)
      expect { loader.load(:test, 2025) }.to output(
        /Multiple XSD files found.*Ignored:/
      ).to_stderr
    ensure
      FileUtils.rm_rf(temp_path)
    end
  end
end
