# frozen_string_literal: true

require "nokogiri"

module AmsfSurvey
  module Taxonomy
    # Parses XBRL definition linkbase files (_def.xml) to identify dimensional fields.
    #
    # Dimensional fields require country-breakdown XBRL output - multiple facts,
    # one per country with its own context containing a dimension segment.
    #
    # In the real estate taxonomy, fields in the Abstract_aAC group are connected
    # to CountryTableaAC hypercube and require dimensional breakdown.
    class DimensionParser
      LINK_NS = "http://www.xbrl.org/2003/linkbase"
      XLINK_NS = "http://www.w3.org/1999/xlink"
      DIM_ARCROLE = "http://xbrl.org/int/dim/arcrole/domain-member"

      # Pattern to identify dimensional abstract groups (e.g., Abstract_aAC)
      # These are connected to hypercubes for dimensional breakdowns
      DIMENSIONAL_ABSTRACT_PATTERN = /Abstract_aAC\z/

      def initialize(def_path)
        @def_path = def_path
      end

      # Parse the definition file and return set of dimensional field IDs.
      #
      # @return [Set<Symbol>] field IDs requiring dimensional breakdown
      def parse
        return Set.new unless File.exist?(@def_path)

        doc = parse_document
        extract_dimensional_fields(doc)
      end

      private

      def parse_document
        Nokogiri::XML(File.read(@def_path)) { |config| config.strict }
      rescue Nokogiri::XML::SyntaxError => e
        warn "[DimensionParser] Error parsing #{@def_path}: #{e.message}"
        Nokogiri::XML("")
      end

      # Extract all field IDs that are members of dimensional abstract groups.
      #
      # @param doc [Nokogiri::XML::Document] parsed definition linkbase
      # @return [Set<Symbol>] dimensional field IDs
      def extract_dimensional_fields(doc)
        dimensional_fields = Set.new

        # Find all definitionArc elements with domain-member arcrole
        arcs = doc.xpath(
          "//link:definitionArc[@xlink:arcrole='#{DIM_ARCROLE}']",
          "link" => LINK_NS,
          "xlink" => XLINK_NS
        )

        arcs.each do |arc|
          from_label = arc["xlink:from"]
          to_label = arc["xlink:to"]

          next unless from_label && to_label

          # Check if the source is a dimensional abstract
          if DIMENSIONAL_ABSTRACT_PATTERN.match?(from_label)
            # Extract field ID from target label (e.g., "strix_a1204S1" -> :a1204S1)
            field_id = extract_field_id(to_label)
            dimensional_fields << field_id if field_id
          end
        end

        dimensional_fields
      end

      # Extract field ID from XBRL locator label.
      #
      # @param label [String] e.g., "strix_a1204S1"
      # @return [Symbol, nil] e.g., :a1204S1
      def extract_field_id(label)
        return nil unless label

        # Remove namespace prefix (e.g., "strix_") - only the first segment before underscore
        # that matches the taxonomy namespace prefix pattern
        field_name = label.sub(/\Astrix_/, "")
        return nil if field_name.empty? || field_name == label

        field_name.to_sym
      end
    end
  end
end
