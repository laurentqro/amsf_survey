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

    describe AmsfSurvey::MissingSemanticMappingError do
      let(:taxonomy_path) { "/path/to/taxonomy/2025" }
      let(:error) { described_class.new(taxonomy_path) }

      it "inherits from TaxonomyLoadError" do
        expect(described_class.superclass).to eq(AmsfSurvey::TaxonomyLoadError)
      end

      it "stores the taxonomy path" do
        expect(error.taxonomy_path).to eq(taxonomy_path)
      end

      it "includes the taxonomy path in the message" do
        expect(error.message).to eq("Semantic mappings file not found in: #{taxonomy_path}")
      end
    end
  end
end
