# frozen_string_literal: true

require "nokogiri"

module AmsfSurvey
  module Taxonomy
    # Parses XBRL schema (.xsd) files to extract field definitions and types.
    class SchemaParser
      XBRLI_NS = "http://www.xbrl.org/2003/instance"

      TYPE_MAPPING = {
        "xbrli:integerItemType" => :integer,
        "xbrli:stringItemType" => :string,
        "xbrli:monetaryItemType" => :monetary,
        "xbrli:booleanItemType" => :boolean
      }.freeze

      MAX_FIELDS = 10_000

      def initialize(xsd_path)
        @xsd_path = xsd_path
      end

      def parse
        validate_file!
        doc = parse_document

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
        enumeration_values = extract_enumeration(element)

        type, xbrl_type = determine_type(type_attr, enumeration_values)

        {
          id: id,
          type: type,
          xbrl_type: xbrl_type,
          valid_values: enumeration_values
        }
      end

      def extract_enumeration(element)
        enums = element.xpath(".//xs:enumeration/@value", "xs" => "http://www.w3.org/2001/XMLSchema")
        return nil if enums.empty?

        enums.map(&:value)
      end

      BOOLEAN_PATTERNS = [
        %w[Non Oui],  # French
        %w[No Yes]    # English
      ].freeze

      def determine_type(type_attr, enumeration_values)
        if enumeration_values
          if BOOLEAN_PATTERNS.include?(enumeration_values.sort)
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
    end
  end
end
