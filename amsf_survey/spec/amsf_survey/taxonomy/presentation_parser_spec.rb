# frozen_string_literal: true

RSpec.describe AmsfSurvey::Taxonomy::PresentationParser do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }
  let(:pre_path) { File.join(fixtures_path, "test_survey_pre.xml") }

  describe "#parse" do
    subject(:result) { described_class.new(pre_path).parse }

    it "returns an array of section definitions" do
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end

    describe "section ordering" do
      it "returns sections in document order" do
        section_ids = result.map { |s| s[:id] }
        expect(section_ids).to eq(%i[Link_General Link_Details])
      end

      it "assigns sequential order values" do
        orders = result.map { |s| s[:order] }
        expect(orders).to eq([1, 2])
      end
    end

    describe "section structure" do
      let(:general_section) { result.find { |s| s[:id] == :Link_General } }
      let(:details_section) { result.find { |s| s[:id] == :Link_Details } }

      it "extracts section name from role URI" do
        expect(general_section[:name]).to eq("Link_General")
        expect(details_section[:name]).to eq("Link_Details")
      end

      it "lists field IDs in presentation order" do
        expect(general_section[:field_ids]).to eq(%i[tGATE t001 t002])
        expect(details_section[:field_ids]).to eq(%i[t003 t004])
      end

      it "assigns field order within section" do
        expect(general_section[:field_orders]).to eq({ tGATE: 1, t001: 2, t002: 3 })
        expect(details_section[:field_orders]).to eq({ t003: 1, t004: 2 })
      end
    end
  end

  describe "error handling" do
    it "raises MissingTaxonomyFileError for missing file" do
      parser = described_class.new("/nonexistent/file_pre.xml")
      expect { parser.parse }.to raise_error(
        AmsfSurvey::MissingTaxonomyFileError,
        /file_pre\.xml/
      )
    end

    it "raises MalformedTaxonomyError for invalid XML" do
      invalid_path = File.join(fixtures_path, "invalid_pre.xml")
      File.write(invalid_path, "<invalid><unclosed>")

      parser = described_class.new(invalid_path)
      expect { parser.parse }.to raise_error(AmsfSurvey::MalformedTaxonomyError)
    ensure
      File.delete(invalid_path) if File.exist?(invalid_path)
    end
  end
end
