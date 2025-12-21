# frozen_string_literal: true

RSpec.describe AmsfSurvey::Taxonomy::LabelParser do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }
  let(:lab_path) { File.join(fixtures_path, "test_survey_lab.xml") }

  describe "#parse" do
    subject(:result) { described_class.new(lab_path).parse }

    it "returns a hash of labels by field ID" do
      expect(result).to be_a(Hash)
    end

    it "extracts labels for all fields" do
      expect(result.keys).to include(:tGATE, :t001, :t002, :t003, :t004)
    end

    describe "label content" do
      it "strips HTML from labels" do
        expect(result[:tGATE][:label]).to eq("Avez-vous effectue des activites?")
        expect(result[:t001][:label]).to eq("Nombre total de clients")
      end

      it "strips HTML tags like <b> from labels" do
        expect(result[:t003][:label]).to eq("Montant total")
      end

      it "handles plain text labels without HTML" do
        expect(result[:t002][:label]).to eq("Commentaires")
      end
    end

    describe "verbose labels" do
      it "extracts verbose labels when present" do
        expect(result[:tGATE][:verbose_label]).to include("Si non, veuillez expliquer pourquoi")
        expect(result[:t001][:verbose_label]).to include("Incluez tous les clients actifs")
      end

      it "returns nil for verbose_label when not present" do
        expect(result[:t002][:verbose_label]).to be_nil
      end
    end
  end

  describe "error handling" do
    it "raises MissingTaxonomyFileError for missing file" do
      parser = described_class.new("/nonexistent/file_lab.xml")
      expect { parser.parse }.to raise_error(
        AmsfSurvey::MissingTaxonomyFileError,
        /file_lab\.xml/
      )
    end

    it "raises MalformedTaxonomyError for invalid XML" do
      invalid_path = File.join(fixtures_path, "invalid_lab.xml")
      File.write(invalid_path, "<invalid><unclosed>")

      parser = described_class.new(invalid_path)
      expect { parser.parse }.to raise_error(AmsfSurvey::MalformedTaxonomyError)
    ensure
      File.delete(invalid_path) if File.exist?(invalid_path)
    end
  end

end
