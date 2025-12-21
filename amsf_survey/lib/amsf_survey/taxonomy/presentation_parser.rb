# frozen_string_literal: true

require "nokogiri"

module AmsfSurvey
  module Taxonomy
    # Parses XBRL presentation linkbase (_pre.xml) files to extract section structure.
    class PresentationParser
      LINK_NS = "http://www.xbrl.org/2003/linkbase"
      XLINK_NS = "http://www.w3.org/1999/xlink"
      PARENT_CHILD_ARCROLE = "http://www.xbrl.org/2003/arcrole/parent-child"

      def initialize(pre_path)
        @pre_path = pre_path
      end

      def parse
        validate_file!
        doc = parse_document

        sections = []
        section_order = 0

        doc.xpath("//link:presentationLink", "link" => LINK_NS).each do |pres_link|
          section_order += 1
          section = extract_section(pres_link, section_order)
          sections << section if section
        end

        sections
      end

      private

      def validate_file!
        return if File.exist?(@pre_path)

        raise MissingTaxonomyFileError, @pre_path
      end

      def parse_document
        doc = Nokogiri::XML(File.read(@pre_path)) { |config| config.strict }
        errors = doc.errors
        raise MalformedTaxonomyError.new(@pre_path, errors.first&.message) if errors.any?

        doc
      rescue Nokogiri::XML::SyntaxError => e
        raise MalformedTaxonomyError.new(@pre_path, e.message)
      end

      def extract_section(pres_link, section_order)
        role_uri = pres_link.attribute_with_ns("role", XLINK_NS)&.value
        return nil unless role_uri

        section_id = extract_section_id(role_uri)
        section_name = section_id.to_s

        # Build locator map
        locators = {}
        pres_link.xpath("link:loc", "link" => LINK_NS).each do |loc|
          href = loc.attribute_with_ns("href", XLINK_NS)&.value
          label = loc.attribute_with_ns("label", XLINK_NS)&.value
          next unless href && label

          field_id = href.split("#").last&.sub(/^[^_]+_/, "")&.to_sym
          locators[label] = field_id
        end

        # Extract field ordering from arcs
        field_ids = []
        field_orders = {}

        pres_link.xpath("link:presentationArc", "link" => LINK_NS).each do |arc|
          arcrole = arc.attribute_with_ns("arcrole", XLINK_NS)&.value
          next unless arcrole == PARENT_CHILD_ARCROLE

          to_label = arc.attribute_with_ns("to", XLINK_NS)&.value
          order = arc["order"]&.to_i || 0
          field_id = locators[to_label]

          next unless field_id
          # Skip abstract elements (they start with Abstract_)
          next if field_id.to_s.start_with?("Abstract_")

          field_ids << field_id
          field_orders[field_id] = order
        end

        {
          id: section_id,
          name: section_name,
          order: section_order,
          field_ids: field_ids,
          field_orders: field_orders
        }
      end

      def extract_section_id(role_uri)
        # Extract section name from URI like ".../role/Link_General"
        role_uri.split("/").last&.strip&.to_sym
      end
    end
  end
end
