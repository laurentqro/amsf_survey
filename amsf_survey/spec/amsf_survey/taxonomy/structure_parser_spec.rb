# frozen_string_literal: true

require "yaml"

RSpec.describe AmsfSurvey::Taxonomy::StructureParser do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }
  let(:structure_path) { File.join(fixtures_path, "questionnaire_structure.yml") }

  describe "#parse" do
    subject(:result) { described_class.new(structure_path).parse }

    it "returns a hash with sections array" do
      expect(result).to be_a(Hash)
      expect(result[:sections]).to be_an(Array)
    end

    it "parses section titles" do
      titles = result[:sections].map { |s| s[:title] }
      expect(titles).to eq(["General", "Details"])
    end

    it "assigns section numbers based on position" do
      numbers = result[:sections].map { |s| s[:number] }
      expect(numbers).to eq([1, 2])
    end

    it "parses subsections within sections" do
      general = result[:sections].first
      expect(general[:subsections].length).to eq(1)
      expect(general[:subsections].first[:title]).to eq("Activity Status")
    end

    it "assigns subsection numbers based on position within section" do
      general = result[:sections].first
      expect(general[:subsections].first[:number]).to eq(1)
    end

    it "parses questions within subsections" do
      general = result[:sections].first
      subsection = general[:subsections].first
      expect(subsection[:questions].length).to eq(3)
    end

    it "parses field_id as symbol" do
      general = result[:sections].first
      subsection = general[:subsections].first
      expect(subsection[:questions].first[:field_id]).to eq(:tgate)
    end

    it "parses instructions (strips trailing whitespace)" do
      general = result[:sections].first
      subsection = general[:subsections].first
      expect(subsection[:questions].first[:instructions]).to eq(
        "Answer Yes if you performed any regulated activities."
      )
    end

    it "leaves instructions nil when not provided" do
      general = result[:sections].first
      subsection = general[:subsections].first
      expect(subsection[:questions][1][:instructions]).to be_nil
    end

    it "assigns question numbers scoped to section" do
      general = result[:sections].first
      details = result[:sections].last

      general_q_numbers = general[:subsections].flat_map { |s| s[:questions].map { |q| q[:number] } }
      details_q_numbers = details[:subsections].flat_map { |s| s[:questions].map { |q| q[:number] } }

      expect(general_q_numbers).to eq([1, 2, 3])
      expect(details_q_numbers).to eq([1, 2])  # Restarts at 1
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
