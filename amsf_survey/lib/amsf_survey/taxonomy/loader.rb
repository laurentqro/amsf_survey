# frozen_string_literal: true

require "yaml"

module AmsfSurvey
  module Taxonomy
    # Orchestrates parsing of all taxonomy files and builds a Questionnaire.
    class Loader
      def initialize(taxonomy_path)
        @taxonomy_path = taxonomy_path
      end

      def load(industry, year)
        mappings = load_semantic_mappings
        schema_data = parse_schema
        labels = parse_labels
        sections_data = parse_presentation
        xule_data = parse_xule

        sections = build_sections(sections_data, schema_data, labels, mappings, xule_data)

        Questionnaire.new(
          industry: industry,
          year: year,
          sections: sections
        )
      end

      private

      def load_semantic_mappings
        mappings_path = File.join(@taxonomy_path, "semantic_mappings.yml")
        raise MissingSemanticMappingError, @taxonomy_path unless File.exist?(mappings_path)

        yaml = YAML.safe_load(File.read(mappings_path), symbolize_names: true)
        yaml[:fields] || {}
      end

      def parse_schema
        xsd_files = Dir.glob(File.join(@taxonomy_path, "*.xsd"))
        raise MissingTaxonomyFileError, File.join(@taxonomy_path, "*.xsd") if xsd_files.empty?

        SchemaParser.new(xsd_files.first).parse
      end

      def parse_labels
        lab_files = Dir.glob(File.join(@taxonomy_path, "*_lab.xml"))
        return {} if lab_files.empty?

        LabelParser.new(lab_files.first).parse
      end

      def parse_presentation
        pre_files = Dir.glob(File.join(@taxonomy_path, "*_pre.xml"))
        return [] if pre_files.empty?

        PresentationParser.new(pre_files.first).parse
      end

      def parse_xule
        xule_files = Dir.glob(File.join(@taxonomy_path, "*.xule"))
        return { gate_rules: {}, gate_fields: [] } if xule_files.empty?

        XuleParser.new(xule_files.first).parse
      end

      def build_sections(sections_data, schema_data, labels, mappings, xule_data)
        sections_data.map do |section_data|
          fields = build_fields(section_data, schema_data, labels, mappings, xule_data)

          Section.new(
            id: section_data[:id],
            name: section_data[:name],
            order: section_data[:order],
            fields: fields
          )
        end
      end

      def build_fields(section_data, schema_data, labels, mappings, xule_data)
        section_data[:field_ids].map do |field_id|
          build_field(field_id, section_data, schema_data, labels, mappings, xule_data)
        end.compact
      end

      def build_field(field_id, section_data, schema_data, labels, mappings, xule_data)
        schema = schema_data[field_id]
        return nil unless schema

        label_data = labels[field_id] || {}
        mapping = mappings[field_id] || {}

        # Determine semantic name and source type from mapping
        name = mapping[:name]&.to_sym || field_id
        source_type = mapping[:source_type]&.to_sym || :entry_only

        # Determine if this is a gate field
        is_gate = xule_data[:gate_fields].include?(field_id)

        # Get dependencies from xule rules
        depends_on = xule_data[:gate_rules][field_id] || {}

        Field.new(
          id: field_id,
          name: name,
          type: schema[:type],
          xbrl_type: schema[:xbrl_type],
          source_type: source_type,
          label: label_data[:label] || field_id.to_s,
          verbose_label: label_data[:verbose_label],
          valid_values: schema[:valid_values],
          section_id: section_data[:id],
          order: section_data[:field_orders][field_id] || 0,
          depends_on: depends_on,
          gate: is_gate
        )
      end
    end
  end
end
