# frozen_string_literal: true

require "cgi"
require "nokogiri"

module AmsfSurvey
  module Taxonomy
    # Parses XBRL schema (.xsd) files to extract field definitions and types.
    #
    # == Boolean Detection
    #
    # Two-value enumerations are classified as :boolean if they match known
    # Yes/No patterns. Currently supported patterns (case-insensitive):
    #
    # - French: "Oui" / "Non"
    # - English: "Yes" / "No"
    #
    # === Known Limitations
    #
    # Other boolean representations will be classified as :enum instead:
    # - "Vrai" / "Faux" (French True/False)
    # - "1" / "0" (numeric)
    # - "True" / "False" (English)
    # - "Ja" / "Nein" (German)
    #
    # This is intentional: only recognized Yes/No patterns get gate logic
    # treatment. Other two-value enums are treated as regular enumerations.
    #
    # To add support for additional patterns, extend BOOLEAN_PATTERNS.
    #
    class SchemaParser
      XBRLI_NS = "http://www.xbrl.org/2003/instance"

      TYPE_MAPPING = {
        "xbrli:integerItemType" => :integer,
        "xbrli:decimalItemType" => :decimal,
        "xbrli:stringItemType" => :string,
        "xbrli:monetaryItemType" => :monetary,
        "xbrli:booleanItemType" => :boolean,
        "xbrli:pureItemType" => :percentage,
        "xbrli:dateItemType" => :date
      }.freeze

      MAX_FIELDS = 10_000

      # The targetNamespace extracted from the XSD, available after parse
      attr_reader :target_namespace

      def initialize(xsd_path)
        @xsd_path = xsd_path
        @target_namespace = nil
      end

      def parse
        validate_file!
        doc = parse_document

        @target_namespace = extract_target_namespace(doc)

        elements = doc.xpath("//xs:element[@abstract='false']", "xs" => "http://www.w3.org/2001/XMLSchema")
        validate_field_count!(elements.size)

        result = {}

        elements.each do |element|
          field_data = extract_field(element)
          result[field_data[:id]] = field_data if field_data
        end

        result
      end

      private

      def extract_target_namespace(doc)
        schema_element = doc.root
        return nil unless schema_element

        schema_element["targetNamespace"]
      end

      def validate_file!
        return if File.exist?(@xsd_path)

        raise MissingTaxonomyFileError, @xsd_path
      end

      def validate_field_count!(count)
        return if count <= MAX_FIELDS

        raise TaxonomyLoadError, "Taxonomy exceeds maximum field count (#{count} > #{MAX_FIELDS})"
      end

      def parse_document
        doc = Nokogiri::XML(File.read(@xsd_path)) { |config| config.strict }
        errors = doc.errors
        raise MalformedTaxonomyError.new(@xsd_path, errors.first&.message) if errors.any?

        doc
      rescue Nokogiri::XML::SyntaxError => e
        raise MalformedTaxonomyError.new(@xsd_path, e.message)
      end

      def extract_field(element)
        name = element["name"]
        return nil unless name

        # Symbols are appropriate: bounded set from official taxonomy, cached, fast lookup
        id = name.to_sym
        type_attr = element["type"]

        # Handle inline complexType restrictions (e.g., a1204S1 with pureItemType)
        type_attr ||= extract_inline_restriction_base(element)

        enumeration_values = extract_enumeration(element)

        type, xbrl_type = determine_type(type_attr, enumeration_values)

        {
          id: id,
          type: type,
          xbrl_type: xbrl_type,
          valid_values: enumeration_values
        }
      end

      # Extracts the base type from inline complexType/simpleContent/restriction.
      # Some fields like a1204S1 don't have a type attribute but instead define
      # the type inline with a restriction.
      #
      # @param element [Nokogiri::XML::Element] the XSD element
      # @return [String, nil] the base type (e.g., "xbrli:pureItemType") or nil
      def extract_inline_restriction_base(element)
        restriction = element.at_xpath(
          ".//xs:restriction/@base",
          "xs" => "http://www.w3.org/2001/XMLSchema"
        )
        restriction&.value
      end

      def extract_enumeration(element)
        enums = element.xpath(".//xs:enumeration/@value", "xs" => "http://www.w3.org/2001/XMLSchema")
        return nil if enums.empty?

        # Decode HTML entities so apps use human-readable values (e.g., "Par l'entité")
        # The generator re-encodes when writing XBRL for Arelle compatibility
        enums.map { |e| CGI.unescape_html(e.value) }
      end

      # Boolean patterns for Yes/No fields (case-insensitive matching).
      # Sorted alphabetically for consistent comparison.
      BOOLEAN_PATTERNS = [
        %w[non oui],  # French (lowercase for comparison)
        %w[no yes]    # English (lowercase for comparison)
      ].freeze

      def determine_type(type_attr, enumeration_values)
        if enumeration_values
          if boolean_enum?(enumeration_values)
            [:boolean, type_attr || "xbrli:stringItemType"]
          else
            [:enum, type_attr || "xbrli:stringItemType"]
          end
        elsif type_attr && TYPE_MAPPING[type_attr]
          [TYPE_MAPPING[type_attr], type_attr]
        else
          [:string, type_attr || "xbrli:stringItemType"]
        end
      end

      # Checks if enumeration values represent a boolean (Yes/No) field.
      # Case-insensitive to handle variations like "YES"/"NO", "Yes"/"No", etc.
      def boolean_enum?(values)
        return false unless values.size == 2

        normalized = values.map(&:downcase).sort
        BOOLEAN_PATTERNS.include?(normalized)
      end
    end
  end
end
