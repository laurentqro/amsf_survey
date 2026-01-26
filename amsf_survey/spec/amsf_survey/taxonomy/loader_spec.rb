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

    describe "sections from structure file" do
      it "creates sections with auto-numbered values" do
        expect(questionnaire.sections.length).to eq(2)
        expect(questionnaire.sections.map(&:number)).to eq([1, 2])
      end

      it "preserves section titles from structure file" do
        expect(questionnaire.sections.map(&:title)).to eq(["General", "Details"])
      end
    end

    describe "subsections" do
      it "creates subsections within sections" do
        first_section = questionnaire.sections.first
        expect(first_section.subsections.length).to eq(1)
        expect(first_section.subsections.first.title).to eq("Activity Status")
      end

      it "auto-numbers subsections within each section" do
        first_section = questionnaire.sections.first
        expect(first_section.subsections.first.number).to eq(1)
      end
    end

    describe "questions" do
      it "creates questions within subsections" do
        first_subsection = questionnaire.sections.first.subsections.first
        expect(first_subsection.questions.length).to eq(3)
      end

      it "auto-numbers questions scoped to section" do
        # First section has 3 questions: 1, 2, 3
        first_section = questionnaire.sections.first
        question_numbers = first_section.questions.map(&:number)
        expect(question_numbers).to eq([1, 2, 3])

        # Second section restarts at 1
        second_section = questionnaire.sections[1]
        question_numbers = second_section.questions.map(&:number)
        expect(question_numbers).to eq([1, 2])
      end

      it "includes instructions from structure file" do
        first_question = questionnaire.sections.first.subsections.first.questions.first
        expect(first_question.instructions).to include("Answer Yes if you performed")
      end

      it "allows nil instructions when not specified" do
        # t002 has no instructions in the structure file
        third_question = questionnaire.sections.first.subsections.first.questions[2]
        expect(third_question.instructions).to be_nil
      end
    end

    describe "fields wrapped in questions" do
      it "wraps Field with correct XBRL data" do
        question = questionnaire.sections.first.questions.first
        field = question.field

        expect(field.id).to eq(:tgate)
        expect(field.type).to eq(:boolean)
        expect(field.label).to eq("Avez-vous effectue des activites?")
      end

      it "delegates XBRL attributes through Question" do
        question = questionnaire.sections.first.questions.first

        expect(question.id).to eq(:tgate)
        expect(question.type).to eq(:boolean)
        expect(question.label).to eq("Avez-vous effectue des activites?")
      end

      it "preserves XBRL types" do
        t001_question = questionnaire.sections.first.questions[1]
        expect(t001_question.field.xbrl_type).to eq("xbrli:integerItemType")
      end

      it "preserves original casing in xbrl_id" do
        question = questionnaire.sections.first.questions.first
        expect(question.xbrl_id).to eq(:tGATE)
      end
    end

    describe "field lookup" do
      it "supports direct field lookup by lowercase ID" do
        field = questionnaire.field(:tgate)
        expect(field).not_to be_nil
        expect(field.id).to eq(:tgate)
      end

      it "normalizes uppercase to lowercase for lookup" do
        expect(questionnaire.field(:TGATE).id).to eq(:tgate)
        expect(questionnaire.field(:TgAtE).id).to eq(:tgate)
      end
    end

    describe "gate dependencies" do
      it "marks gate fields" do
        gate_field = questionnaire.field(:tgate)
        expect(gate_field.gate?).to be true
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

    describe "valid_values" do
      it "sets valid_values for boolean fields" do
        field = questionnaire.field(:tgate)
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

    describe "labels" do
      it "strips HTML from labels" do
        field = questionnaire.field(:tgate)
        expect(field.label).to eq("Avez-vous effectue des activites?")
      end

      it "includes verbose labels when present" do
        field = questionnaire.field(:tgate)
        expect(field.verbose_label).to include("Si non, veuillez expliquer pourquoi")
      end
    end

    describe "field_count" do
      it "returns total fields across all sections" do
        expect(questionnaire.field_count).to eq(5)
      end
    end
  end

  describe "error handling" do
    describe "UnknownFieldError" do
      it "raises when structure references non-existent field" do
        temp_path = File.join(fixtures_path, "..", "unknown_field_test")
        FileUtils.mkdir_p(temp_path)
        FileUtils.cp(File.join(fixtures_path, "test_survey.xsd"), temp_path)

        # Create structure file with unknown field
        structure_content = <<~YAML
          sections:
            - title: "Test"
              subsections:
                - title: "Sub"
                  questions:
                    - field_id: nonexistent_field
        YAML
        File.write(File.join(temp_path, "questionnaire_structure.yml"), structure_content)

        loader = described_class.new(temp_path)
        expect { loader.load(:test, 2025) }.to raise_error(
          AmsfSurvey::UnknownFieldError,
          /nonexistent_field/
        )
      ensure
        FileUtils.rm_rf(temp_path)
      end
    end

    describe "DuplicateFieldError" do
      it "raises when field appears twice in structure" do
        temp_path = File.join(fixtures_path, "..", "duplicate_field_test")
        FileUtils.mkdir_p(temp_path)
        FileUtils.cp(File.join(fixtures_path, "test_survey.xsd"), temp_path)
        FileUtils.cp(File.join(fixtures_path, "test_survey_lab.xml"), temp_path)

        # Create structure file with duplicate field
        structure_content = <<~YAML
          sections:
            - title: "Section 1"
              subsections:
                - title: "Sub 1"
                  questions:
                    - field_id: tgate
            - title: "Section 2"
              subsections:
                - title: "Sub 2"
                  questions:
                    - field_id: tgate
        YAML
        File.write(File.join(temp_path, "questionnaire_structure.yml"), structure_content)

        loader = described_class.new(temp_path)
        expect { loader.load(:test, 2025) }.to raise_error(
          AmsfSurvey::DuplicateFieldError,
          /tgate.*Section 2/
        )
      ensure
        FileUtils.rm_rf(temp_path)
      end
    end

    describe "MissingStructureFileError" do
      it "raises when questionnaire_structure.yml is missing" do
        temp_path = File.join(fixtures_path, "..", "no_structure_test")
        FileUtils.mkdir_p(temp_path)
        FileUtils.cp(File.join(fixtures_path, "test_survey.xsd"), temp_path)

        loader = described_class.new(temp_path)
        expect { loader.load(:test, 2025) }.to raise_error(
          AmsfSurvey::MissingStructureFileError,
          /questionnaire_structure\.yml/
        )
      ensure
        FileUtils.rm_rf(temp_path)
      end
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

  describe "multiple file handling" do
    it "warns when multiple XSD files are found" do
      temp_path = File.join(fixtures_path, "..", "multi_xsd")
      FileUtils.mkdir_p(temp_path)
      FileUtils.cp(File.join(fixtures_path, "test_survey.xsd"), temp_path)
      FileUtils.cp(File.join(fixtures_path, "test_survey.xsd"), File.join(temp_path, "extra.xsd"))
      FileUtils.cp(File.join(fixtures_path, "questionnaire_structure.yml"), temp_path)

      loader = described_class.new(temp_path)
      expect { loader.load(:test, 2025) }.to output(
        /Multiple XSD files found.*Ignored:/
      ).to_stderr
    ensure
      FileUtils.rm_rf(temp_path)
    end
  end
end
