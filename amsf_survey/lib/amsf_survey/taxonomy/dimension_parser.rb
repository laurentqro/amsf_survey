# frozen_string_literal: true

require "nokogiri"

module AmsfSurvey
  module Taxonomy
    # Parses XBRL definition linkbase files (_def.xml) to identify dimensional fields
    # and extract dimension metadata (dimension name, member prefix).
    #
    # Dimensional fields require country-breakdown XBRL output - multiple facts,
    # one per country with its own context containing a dimension segment.
    #
    # Pattern matching is configurable via taxonomy.yml dimension settings:
    #   dimension:
    #     abstract_pattern: "Abstract_aAC$"       # Pattern for dimensional abstract groups
    #     member_suffix_pattern: "[A-Z]{2}$"      # Pattern for country code suffix
    class DimensionParser
      LINK_NS = "http://www.xbrl.org/2003/linkbase"
      XLINK_NS = "http://www.w3.org/1999/xlink"

      # XBRL dimensional arcroles
      DOMAIN_MEMBER_ARCROLE = "http://xbrl.org/int/dim/arcrole/domain-member"
      HYPERCUBE_DIMENSION_ARCROLE = "http://xbrl.org/int/dim/arcrole/hypercube-dimension"
      DIMENSION_DOMAIN_ARCROLE = "http://xbrl.org/int/dim/arcrole/dimension-domain"

      # Default pattern to identify dimensional abstract groups (e.g., Abstract_aAC)
      # Can be overridden via taxonomy.yml dimension.abstract_pattern
      DEFAULT_ABSTRACT_PATTERN = /Abstract_aAC\z/

      # Default pattern for dimension member suffix (ISO 3166-1 alpha-2 country codes)
      # Can be overridden via taxonomy.yml dimension.member_suffix_pattern
      DEFAULT_MEMBER_SUFFIX_PATTERN = /[A-Z]{2}\z/

      # @param def_path [String] path to the _def.xml file
      # @param config [Hash] dimension configuration from taxonomy.yml
      # @option config [String] :abstract_pattern regex pattern for dimensional abstracts
      # @option config [String] :member_suffix_pattern regex pattern for member suffixes
      def initialize(def_path, config = {})
        @def_path = def_path
        @abstract_pattern = build_pattern(config[:abstract_pattern], DEFAULT_ABSTRACT_PATTERN)
        @member_suffix_pattern = build_pattern(config[:member_suffix_pattern], DEFAULT_MEMBER_SUFFIX_PATTERN)
      end

      # Parse the definition file and return dimension metadata.
      #
      # @return [Hash] with keys:
      #   - :dimensional_fields [Set<Symbol>] field IDs requiring dimensional breakdown
      #   - :dimension_name [String, nil] the dimension element name (e.g., "CountryDimension")
      #   - :member_prefix [String, nil] the prefix for member IDs (e.g., "sdl")
      def parse
        return empty_result unless File.exist?(@def_path)

        doc = parse_document
        return empty_result if doc.root.nil?

        {
          dimensional_fields: extract_dimensional_fields(doc),
          dimension_name: extract_dimension_name(doc),
          member_prefix: extract_member_prefix(doc)
        }
      end

      private

      # Build a Regexp from a string pattern, or use the default.
      #
      # @param pattern_string [String, nil] regex pattern from config
      # @param default [Regexp] default pattern to use if config is nil
      # @return [Regexp] compiled regex
      def build_pattern(pattern_string, default)
        return default if pattern_string.nil? || pattern_string.empty?

        Regexp.new(pattern_string)
      rescue RegexpError => e
        warn "[DimensionParser] Invalid regex pattern '#{pattern_string}': #{e.message}. Using default."
        default
      end

      def empty_result
        {
          dimensional_fields: Set.new,
          dimension_name: nil,
          member_prefix: nil
        }
      end

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

        arcs = doc.xpath(
          "//link:definitionArc[@xlink:arcrole='#{DOMAIN_MEMBER_ARCROLE}']",
          "link" => LINK_NS,
          "xlink" => XLINK_NS
        )

        arcs.each do |arc|
          from_label = arc["xlink:from"]
          to_label = arc["xlink:to"]

          next unless from_label && to_label

          if @abstract_pattern.match?(from_label)
            field_id = extract_field_id(to_label)
            dimensional_fields << field_id if field_id
          end
        end

        dimensional_fields
      end

      # Extract dimension name from hypercube-dimension arcs.
      # Finds the dimension element connected to a hypercube (e.g., CountryDimension).
      #
      # @param doc [Nokogiri::XML::Document] parsed definition linkbase
      # @return [String, nil] dimension name without namespace prefix
      def extract_dimension_name(doc)
        arc = doc.at_xpath(
          "//link:definitionArc[@xlink:arcrole='#{HYPERCUBE_DIMENSION_ARCROLE}']",
          "link" => LINK_NS,
          "xlink" => XLINK_NS
        )

        return nil unless arc

        dimension_label = arc["xlink:to"]
        strip_namespace_prefix(dimension_label)
      end

      # Extract member prefix by analyzing domain-member relationships.
      # Looks for members connected to a domain (e.g., CountryDomain -> sdlFR).
      #
      # @param doc [Nokogiri::XML::Document] parsed definition linkbase
      # @return [String, nil] common prefix for dimension members
      def extract_member_prefix(doc)
        # First find the domain from dimension-domain arc
        domain_arc = doc.at_xpath(
          "//link:definitionArc[@xlink:arcrole='#{DIMENSION_DOMAIN_ARCROLE}']",
          "link" => LINK_NS,
          "xlink" => XLINK_NS
        )

        return nil unless domain_arc

        domain_label = domain_arc["xlink:to"]
        return nil unless domain_label

        # Find members connected to this domain
        member_arcs = doc.xpath(
          "//link:definitionArc[@xlink:arcrole='#{DOMAIN_MEMBER_ARCROLE}'][@xlink:from='#{domain_label}']",
          "link" => LINK_NS,
          "xlink" => XLINK_NS
        )

        return nil if member_arcs.empty?

        # Extract prefix from first member (e.g., "strix_sdlFR" -> "sdl")
        first_member = member_arcs.first["xlink:to"]
        extract_member_prefix_from_label(first_member)
      end

      # Extract field ID from XBRL locator label.
      #
      # @param label [String] e.g., "strix_a1204S1"
      # @return [Symbol, nil] e.g., :a1204S1
      def extract_field_id(label)
        return nil unless label

        field_name = strip_namespace_prefix(label)
        return nil if field_name.nil? || field_name.empty?

        field_name.to_sym
      end

      # Remove namespace prefix from label.
      # Logs a warning if the expected prefix is not found (may indicate taxonomy inconsistency).
      #
      # @param label [String] e.g., "strix_CountryDimension"
      # @return [String, nil] e.g., "CountryDimension"
      def strip_namespace_prefix(label)
        return nil unless label

        # Remove "strix_" prefix (common AMSF convention)
        result = label.sub(/\Astrix_/, "")
        if result == label
          warn "[DimensionParser] Label '#{label}' does not have expected 'strix_' prefix"
          return nil
        end
        result
      end

      # Extract the common prefix from a dimension member label.
      # Members follow pattern: namespace_prefixSUFFIX (e.g., strix_sdlFR)
      # The suffix pattern is configurable (defaults to ISO 3166-1 alpha-2 country codes).
      #
      # @param label [String] e.g., "strix_sdlFR"
      # @return [String, nil] e.g., "sdl"
      def extract_member_prefix_from_label(label)
        member_id = strip_namespace_prefix(label)
        return nil unless member_id

        # Extract everything before the suffix pattern (e.g., country code)
        # Build a capture pattern: (.+?) followed by the suffix
        capture_pattern = /\A(.+?)#{@member_suffix_pattern.source}/
        match = member_id.match(capture_pattern)

        unless match
          warn "[DimensionParser] Member '#{member_id}' does not match suffix pattern #{@member_suffix_pattern.inspect}"
          return nil
        end

        match[1]
      end
    end
  end
end
