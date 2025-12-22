# frozen_string_literal: true

RSpec.describe AmsfSurvey::Taxonomy::SchemaParser do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }
  let(:xsd_path) { File.join(fixtures_path, "test_survey.xsd") }

  describe "#parse" do
    subject(:result) { described_class.new(xsd_path).parse }

    it "returns a hash of field definitions" do
      expect(result).to be_a(Hash)
    end

    it "extracts field IDs" do
      expect(result.keys).to include(:tGATE, :t001, :t002, :t003, :t004)
    end

    it "excludes abstract elements" do
      expect(result.keys).not_to include(:Abstract_General, :Abstract_Details)
    end

    describe "type mapping" do
      it "maps integer types correctly" do
        expect(result[:t001][:type]).to eq(:integer)
        expect(result[:t001][:xbrl_type]).to eq("xbrli:integerItemType")
      end

      it "maps string types correctly" do
        expect(result[:t002][:type]).to eq(:string)
        expect(result[:t002][:xbrl_type]).to eq("xbrli:stringItemType")
      end

      it "maps monetary types correctly" do
        expect(result[:t003][:type]).to eq(:monetary)
        expect(result[:t003][:xbrl_type]).to eq("xbrli:monetaryItemType")
      end

      it "maps Oui/Non enum to boolean (French)" do
        expect(result[:tGATE][:type]).to eq(:boolean)
        expect(result[:tGATE][:valid_values]).to eq(%w[Oui Non])
      end

      it "maps Yes/No enum to boolean (English)" do
        english_xsd = <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <schema xmlns="http://www.w3.org/2001/XMLSchema"
                  xmlns:xbrli="http://www.xbrl.org/2003/instance">
            <element abstract="false" id="test_bool" name="bool_field"
                     substitutionGroup="xbrli:item" xbrli:periodType="instant">
              <simpleType>
                <restriction base="string">
                  <enumeration value="Yes"/>
                  <enumeration value="No"/>
                </restriction>
              </simpleType>
            </element>
          </schema>
        XML
        temp_path = File.join(fixtures_path, "temp_english_bool.xsd")
        File.write(temp_path, english_xsd)

        result = described_class.new(temp_path).parse
        expect(result[:bool_field][:type]).to eq(:boolean)
        expect(result[:bool_field][:valid_values]).to eq(%w[Yes No])
      ensure
        File.delete(temp_path) if File.exist?(temp_path)
      end

      it "maps YES/NO enum to boolean (case-insensitive)" do
        uppercase_xsd = <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <schema xmlns="http://www.w3.org/2001/XMLSchema"
                  xmlns:xbrli="http://www.xbrl.org/2003/instance">
            <element abstract="false" id="test_upper" name="upper_field"
                     substitutionGroup="xbrli:item" xbrli:periodType="instant">
              <simpleType>
                <restriction base="string">
                  <enumeration value="YES"/>
                  <enumeration value="NO"/>
                </restriction>
              </simpleType>
            </element>
          </schema>
        XML
        temp_path = File.join(fixtures_path, "temp_uppercase_bool.xsd")
        File.write(temp_path, uppercase_xsd)

        result = described_class.new(temp_path).parse
        expect(result[:upper_field][:type]).to eq(:boolean)
        # Original case preserved in valid_values
        expect(result[:upper_field][:valid_values]).to eq(%w[YES NO])
      ensure
        File.delete(temp_path) if File.exist?(temp_path)
      end

      it "maps OUI/NON enum to boolean (French uppercase)" do
        french_upper_xsd = <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <schema xmlns="http://www.w3.org/2001/XMLSchema"
                  xmlns:xbrli="http://www.xbrl.org/2003/instance">
            <element abstract="false" id="test_fr" name="french_field"
                     substitutionGroup="xbrli:item" xbrli:periodType="instant">
              <simpleType>
                <restriction base="string">
                  <enumeration value="OUI"/>
                  <enumeration value="NON"/>
                </restriction>
              </simpleType>
            </element>
          </schema>
        XML
        temp_path = File.join(fixtures_path, "temp_french_upper.xsd")
        File.write(temp_path, french_upper_xsd)

        result = described_class.new(temp_path).parse
        expect(result[:french_field][:type]).to eq(:boolean)
        expect(result[:french_field][:valid_values]).to eq(%w[OUI NON])
      ensure
        File.delete(temp_path) if File.exist?(temp_path)
      end

      it "maps multi-value enum correctly" do
        expect(result[:t004][:type]).to eq(:enum)
        expect(result[:t004][:valid_values]).to eq(["Option A", "Option B", "Option C"])
      end

      it "falls back to string for unknown types" do
        # Create a temporary XSD with an unknown type
        unknown_type_xsd = <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <schema xmlns="http://www.w3.org/2001/XMLSchema"
                  xmlns:xbrli="http://www.xbrl.org/2003/instance">
            <element abstract="false" id="test_unknown" name="unknown"
                     type="xbrli:unknownItemType"
                     substitutionGroup="xbrli:item" xbrli:periodType="instant"/>
          </schema>
        XML
        temp_path = File.join(fixtures_path, "temp_unknown.xsd")
        File.write(temp_path, unknown_type_xsd)

        result = described_class.new(temp_path).parse
        expect(result[:unknown][:type]).to eq(:string)
        expect(result[:unknown][:xbrl_type]).to eq("xbrli:unknownItemType")
      ensure
        File.delete(temp_path) if File.exist?(temp_path)
      end
    end

  end

  describe "error handling" do
    it "raises MissingTaxonomyFileError for missing file" do
      parser = described_class.new("/nonexistent/file.xsd")
      expect { parser.parse }.to raise_error(
        AmsfSurvey::MissingTaxonomyFileError,
        /file\.xsd/
      )
    end

    it "raises MalformedTaxonomyError for invalid XML" do
      # Create a temporary invalid file
      invalid_path = File.join(fixtures_path, "invalid.xsd")
      File.write(invalid_path, "<invalid><unclosed>")

      parser = described_class.new(invalid_path)
      expect { parser.parse }.to raise_error(AmsfSurvey::MalformedTaxonomyError)
    ensure
      File.delete(invalid_path) if File.exist?(invalid_path)
    end

    it "raises TaxonomyLoadError when field count exceeds maximum" do
      # Temporarily lower the max for testing
      original_max = described_class::MAX_FIELDS
      stub_const("AmsfSurvey::Taxonomy::SchemaParser::MAX_FIELDS", 2)

      expect { described_class.new(xsd_path).parse }.to raise_error(
        AmsfSurvey::TaxonomyLoadError,
        /exceeds maximum field count/
      )
    end
  end
end
