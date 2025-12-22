# frozen_string_literal: true

require "nokogiri"

module AmsfSurvey
  module Taxonomy
    # Parses XBRL label linkbase (_lab.xml) files to extract field labels.
    class LabelParser
      LINK_NS = "http://www.xbrl.org/2003/linkbase"
      XLINK_NS = "http://www.w3.org/1999/xlink"
      LABEL_ROLE = "http://www.xbrl.org/2003/role/label"
      VERBOSE_ROLE = "http://www.xbrl.org/2003/role/verboseLabel"

      def initialize(lab_path)
        @lab_path = lab_path
      end

      def parse
        validate_file!
        doc = parse_document

        labels = {}

        # Find all locators to map label references to field IDs
        locators = extract_locators(doc)

        # Extract labels and verbose labels
        doc.xpath("//link:label", "link" => LINK_NS).each do |label_el|
          label_ref = label_el.attribute_with_ns("label", XLINK_NS)&.value
          role = label_el.attribute_with_ns("role", XLINK_NS)&.value
          content = strip_html(label_el.text)

          # Find the field ID for this label
          field_id = find_field_id(locators, label_ref, doc)
          next unless field_id

          labels[field_id] ||= {}

          case role
          when LABEL_ROLE
            labels[field_id][:label] = content
          when VERBOSE_ROLE
            labels[field_id][:verbose_label] = content
          end
        end

        labels
      end

      private

      def validate_file!
        return if File.exist?(@lab_path)

        raise MissingTaxonomyFileError, @lab_path
      end

      def parse_document
        doc = Nokogiri::XML(File.read(@lab_path)) { |config| config.strict }
        errors = doc.errors
        raise MalformedTaxonomyError.new(@lab_path, errors.first&.message) if errors.any?

        doc
      rescue Nokogiri::XML::SyntaxError => e
        raise MalformedTaxonomyError.new(@lab_path, e.message)
      end

      def extract_locators(doc)
        locators = {}
        doc.xpath("//link:loc", "link" => LINK_NS).each do |loc|
          href = loc.attribute_with_ns("href", XLINK_NS)&.value
          label = loc.attribute_with_ns("label", XLINK_NS)&.value
          next unless href && label

          # Extract field ID from href like "schema.xsd#test_t001"
          field_id = href.split("#").last&.sub(/^[^_]+_/, "")&.to_sym
          locators[label] = field_id
        end
        locators
      end

      def find_field_id(locators, label_ref, doc)
        # Label refs are like "label_test_tGATE" - find the arc that maps to a locator
        arc = doc.at_xpath(
          "//link:labelArc[@xlink:to='#{label_ref}']",
          "link" => LINK_NS,
          "xlink" => XLINK_NS
        )
        return nil unless arc

        from_ref = arc.attribute_with_ns("from", XLINK_NS)&.value
        locators[from_ref]
      end

      def strip_html(html_string)
        return "" if html_string.nil? || html_string.empty?

        Nokogiri::HTML.fragment(html_string).text.strip
      end
    end
  end
end
