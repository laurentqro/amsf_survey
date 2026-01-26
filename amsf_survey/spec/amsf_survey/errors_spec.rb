# frozen_string_literal: true

RSpec.describe AmsfSurvey do
  describe "Error classes" do
    describe AmsfSurvey::Error do
      it "inherits from StandardError" do
        expect(AmsfSurvey::Error.superclass).to eq(StandardError)
      end
    end

    describe AmsfSurvey::TaxonomyLoadError do
      it "inherits from AmsfSurvey::Error" do
        expect(AmsfSurvey::TaxonomyLoadError.superclass).to eq(AmsfSurvey::Error)
      end
    end

    describe AmsfSurvey::MissingTaxonomyFileError do
      let(:file_path) { "/path/to/missing/file.xsd" }
      let(:error) { described_class.new(file_path) }

      it "inherits from TaxonomyLoadError" do
        expect(described_class.superclass).to eq(AmsfSurvey::TaxonomyLoadError)
      end

      it "stores the file path" do
        expect(error.file_path).to eq(file_path)
      end

      it "includes the file path in the message" do
        expect(error.message).to eq("Taxonomy file not found: #{file_path}")
      end
    end

    describe AmsfSurvey::MalformedTaxonomyError do
      let(:file_path) { "/path/to/malformed/file.xml" }

      context "without parse error details" do
        let(:error) { described_class.new(file_path) }

        it "inherits from TaxonomyLoadError" do
          expect(described_class.superclass).to eq(AmsfSurvey::TaxonomyLoadError)
        end

        it "stores the file path" do
          expect(error.file_path).to eq(file_path)
        end

        it "has nil parse_error" do
          expect(error.parse_error).to be_nil
        end

        it "includes the file path in the message" do
          expect(error.message).to eq("Malformed taxonomy file: #{file_path}")
        end
      end

      context "with parse error details" do
        let(:parse_error) { "unexpected token at line 42" }
        let(:error) { described_class.new(file_path, parse_error) }

        it "stores the parse error" do
          expect(error.parse_error).to eq(parse_error)
        end

        it "includes both file path and parse error in the message" do
          expect(error.message).to eq("Malformed taxonomy file: #{file_path} (#{parse_error})")
        end
      end
    end

    describe AmsfSurvey::UnknownFieldError do
      let(:field_id) { :nonexistent_field }
      let(:error) { described_class.new(field_id) }

      it "inherits from AmsfSurvey::Error" do
        expect(described_class.superclass).to eq(AmsfSurvey::Error)
      end

      it "stores the field id" do
        expect(error.field_id).to eq(field_id)
      end

      it "includes the field id in the message" do
        expect(error.message).to eq("Unknown field: #{field_id}")
      end
    end

    describe AmsfSurvey::MissingStructureFileError do
      it "includes file path in message" do
        error = described_class.new("/path/to/missing.yml")
        expect(error.message).to eq("Structure file not found: /path/to/missing.yml")
        expect(error.file_path).to eq("/path/to/missing.yml")
      end

      it "inherits from TaxonomyLoadError" do
        expect(described_class.superclass).to eq(AmsfSurvey::TaxonomyLoadError)
      end
    end

    describe AmsfSurvey::DuplicateFieldError do
      it "includes field id and location in message" do
        error = described_class.new(:aactive, "Section 1, Subsection 2")
        expect(error.message).to eq("Duplicate field 'aactive' in Section 1, Subsection 2")
        expect(error.field_id).to eq(:aactive)
        expect(error.location).to eq("Section 1, Subsection 2")
      end

      it "inherits from TaxonomyLoadError" do
        expect(described_class.superclass).to eq(AmsfSurvey::TaxonomyLoadError)
      end
    end
  end
end
