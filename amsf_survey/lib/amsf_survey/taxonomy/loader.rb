# frozen_string_literal: true

module AmsfSurvey
  module Taxonomy
    # Orchestrates parsing of all taxonomy files and builds a Questionnaire.
    class Loader
      def initialize(taxonomy_path)
        @taxonomy_path = taxonomy_path
      end

      def load(industry, year)
        schema_parser = build_schema_parser
        schema_data = schema_parser.parse
        labels = parse_labels
        sections_data = parse_presentation
        xule_data = parse_xule

        sections = build_sections(sections_data, schema_data, labels, xule_data)

        Questionnaire.new(
          industry: industry,
          year: year,
          sections: sections,
          taxonomy_namespace: schema_parser.target_namespace
        )
      end

      private

      def build_schema_parser
        xsd_files = Dir.glob(File.join(@taxonomy_path, "*.xsd"))
        raise MissingTaxonomyFileError, File.join(@taxonomy_path, "*.xsd") if xsd_files.empty?

        if xsd_files.size > 1
          warn "[TaxonomyLoader] Multiple XSD files found. Using: #{File.basename(xsd_files.first)}. " \
               "Ignored: #{xsd_files[1..].map { |f| File.basename(f) }.join(', ')}"
        end

        SchemaParser.new(xsd_files.first)
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

      def build_sections(sections_data, schema_data, labels, xule_data)
        sections_data.map do |section_data|
          fields = build_fields(section_data, schema_data, labels, xule_data)

          Section.new(
            id: section_data[:id],
            name: section_data[:name],
            order: section_data[:order],
            fields: fields
          )
        end
      end

      def build_fields(section_data, schema_data, labels, xule_data)
        section_data[:field_ids].map do |field_id|
          build_field(field_id, section_data, schema_data, labels, xule_data)
        end.compact
      end

      # Translates XULE "Yes"/"No" literals to actual valid values from the schema.
      # XULE uses English boolean literals, but taxonomies may use French ("Oui"/"Non").
      # Preserves original XBRL ID casing for internal logic.
      #
      # @param xule_deps [Hash, nil] Dependencies from XuleParser (e.g., { tGATE: "Yes" })
      # @param schema_data [Hash] Parsed schema with valid_values for each field
      # @return [Hash] Dependencies with original keys and translated values (e.g., { tGATE: "Oui" })
      def resolve_gate_dependencies(xule_deps, schema_data)
        return {} if xule_deps.nil? || xule_deps.empty?

        xule_deps.each_with_object({}) do |(gate_id, xule_value), result|
          # Preserve original XBRL ID casing for internal logic
          result[gate_id] = translate_gate_value(xule_value, schema_data[gate_id])
        end
      end

      # Maps XULE boolean literal to actual schema value.
      # Falls back to the original value if translation not possible.
      def translate_gate_value(xule_value, gate_schema)
        return xule_value unless gate_schema && gate_schema[:valid_values]

        valid_values = gate_schema[:valid_values]
        return xule_value unless valid_values.size == 2

        # Find the positive value (Oui/Yes/etc.) based on XULE "Yes"
        if xule_value == "Yes"
          find_positive_value(valid_values)
        else
          find_negative_value(valid_values)
        end
      end

      # Finds the "positive" value (Yes, Oui, etc.) from valid_values
      def find_positive_value(valid_values)
        valid_values.find { |v| v.downcase == "yes" || v.downcase == "oui" } || valid_values.first
      end

      # Finds the "negative" value (No, Non, etc.) from valid_values
      def find_negative_value(valid_values)
        valid_values.find { |v| v.downcase == "no" || v.downcase == "non" } || valid_values.last
      end

      def build_field(field_id, section_data, schema_data, labels, xule_data)
        schema = schema_data[field_id]
        return nil unless schema

        label_data = labels[field_id] || {}

        # Determine if this is a gate field
        is_gate = xule_data[:gate_fields].include?(field_id)

        # Get dependencies from xule rules, translating XULE "Yes" to actual valid values
        depends_on = resolve_gate_dependencies(
          xule_data[:gate_rules][field_id],
          schema_data
        )

        Field.new(
          id: field_id,
          type: schema[:type],
          xbrl_type: schema[:xbrl_type],
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
