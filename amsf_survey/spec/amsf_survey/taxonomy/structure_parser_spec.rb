# frozen_string_literal: true

require "yaml"

RSpec.describe AmsfSurvey::Taxonomy::StructureParser do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }
  let(:structure_path) { File.join(fixtures_path, "questionnaire_structure.yml") }

  describe "#parse" do
    subject(:result) { described_class.new(structure_path).parse }

    it "returns a hash with parts array" do
      expect(result).to be_a(Hash)
      expect(result[:parts]).to be_an(Array)
    end

    it "parses part names" do
      names = result[:parts].map { |p| p[:name] }
      expect(names).to eq(["Inherent Risk"])
    end

    it "parses sections within parts" do
      part = result[:parts].first
      expect(part[:sections].length).to eq(2)
      expect(part[:sections].map { |s| s[:title] }).to eq(["General", "Details"])
    end

    it "parses explicit section numbers" do
      part = result[:parts].first
      expect(part[:sections].map { |s| s[:number] }).to eq([1, 2])
    end

    it "parses subsections with string numbers" do
      part = result[:parts].first
      section = part[:sections].first
      expect(section[:subsections].first[:number]).to eq("1.1")
      expect(section[:subsections].first[:title]).to eq("Activity Status")
    end

    it "parses explicit question numbers" do
      part = result[:parts].first
      section = part[:sections].first
      subsection = section[:subsections].first
      expect(subsection[:questions].map { |q| q[:number] }).to eq([1, 2, 3])
    end

    it "parses field_id as lowercase symbol" do
      part = result[:parts].first
      section = part[:sections].first
      subsection = section[:subsections].first
      expect(subsection[:questions].first[:field_id]).to eq(:tgate)
    end

    it "parses instructions" do
      part = result[:parts].first
      section = part[:sections].first
      subsection = section[:subsections].first
      expect(subsection[:questions].first[:instructions]).to eq(
        "Answer Yes if you performed any regulated activities."
      )
    end

    it "leaves instructions nil when not provided" do
      part = result[:parts].first
      section = part[:sections].first
      subsection = section[:subsections].first
      expect(subsection[:questions][1][:instructions]).to be_nil
    end
  end

  describe "error handling" do
    it "raises MissingStructureFileError when file not found" do
      parser = described_class.new("/nonexistent/path.yml")

      expect { parser.parse }.to raise_error(
        AmsfSurvey::MissingStructureFileError,
        /Structure file not found/
      )
    end

    it "raises MalformedTaxonomyError for invalid YAML" do
      invalid_path = File.join(fixtures_path, "invalid.yml")
      File.write(invalid_path, "{ invalid yaml content")

      parser = described_class.new(invalid_path)
      expect { parser.parse }.to raise_error(AmsfSurvey::MalformedTaxonomyError)
    ensure
      File.delete(invalid_path) if File.exist?(invalid_path)
    end
  end
end
