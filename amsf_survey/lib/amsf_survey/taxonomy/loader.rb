# frozen_string_literal: true

module AmsfSurvey
  module Taxonomy
    # Orchestrates parsing of all taxonomy files and builds a Questionnaire.
    # Uses StructureParser for PDF-based section/subsection/question hierarchy.
    class Loader
      def initialize(taxonomy_path)
        @taxonomy_path = taxonomy_path
      end

      def load(industry, year)
        # Parse XBRL files for field data
        schema_parser = build_schema_parser
        schema_data = schema_parser.parse
        labels = parse_labels
        xule_data = parse_xule

        # Build field index from XBRL data
        fields = build_fields(schema_data, labels, xule_data)
        field_index = fields.each_with_object({}) { |f, h| h[f.id] = f }

        # Parse structure file and assemble sections
        structure_data = parse_structure
        sections = build_sections(structure_data[:sections], field_index)

        AmsfSurvey::Questionnaire.new(
          industry: industry,
          year: year,
          sections: sections,
          taxonomy_namespace: schema_parser.target_namespace
        )
      end

      private

      def structure_file_path
        File.join(@taxonomy_path, "questionnaire_structure.yml")
      end

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

      def parse_xule
        xule_files = Dir.glob(File.join(@taxonomy_path, "*.xule"))
        return { gate_rules: {}, gate_fields: [] } if xule_files.empty?

        XuleParser.new(xule_files.first).parse
      end

      def parse_structure
        StructureParser.new(structure_file_path).parse
      end

      def build_fields(schema_data, labels, xule_data)
        schema_data.map do |field_id, schema|
          build_field(field_id, schema, labels, xule_data, schema_data)
        end.compact
      end

      def build_field(field_id, schema, labels, xule_data, schema_data)
        label_data = labels[field_id] || {}
        is_gate = xule_data[:gate_fields].include?(field_id)
        depends_on = resolve_gate_dependencies(xule_data[:gate_rules][field_id], schema_data)

        AmsfSurvey::Field.new(
          id: field_id,
          type: schema[:type],
          xbrl_type: schema[:xbrl_type],
          label: label_data[:label] || field_id.to_s,
          verbose_label: label_data[:verbose_label],
          valid_values: schema[:valid_values],
          section_id: nil, # No longer used - hierarchy is via Question/Subsection/Section
          depends_on: depends_on,
          gate: is_gate
        )
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
          result[gate_id] = translate_gate_value(xule_value, schema_data[gate_id])
        end
      end

      # Maps XULE boolean literal to actual schema value.
      # Falls back to the original value if translation not possible.
      def translate_gate_value(xule_value, gate_schema)
        return xule_value unless gate_schema && gate_schema[:valid_values]

        valid_values = gate_schema[:valid_values]
        return xule_value unless valid_values.size == 2

        if xule_value == "Yes"
          valid_values.find { |v| v.downcase == "yes" || v.downcase == "oui" } || valid_values.first
        else
          valid_values.find { |v| v.downcase == "no" || v.downcase == "non" } || valid_values.last
        end
      end

      def build_sections(sections_data, field_index)
        seen_fields = {}

        sections_data.map do |section_data|
          subsections = section_data[:subsections].map do |sub_data|
            build_subsection(sub_data, field_index, seen_fields, section_data[:title])
          end

          AmsfSurvey::Section.new(
            number: section_data[:number],
            title: section_data[:title],
            subsections: subsections
          )
        end
      end

      def build_subsection(sub_data, field_index, seen_fields, section_title)
        questions = sub_data[:questions].map do |q_data|
          build_question(q_data, field_index, seen_fields, section_title, sub_data[:title])
        end

        AmsfSurvey::Subsection.new(
          number: sub_data[:number],
          title: sub_data[:title],
          questions: questions
        )
      end

      def build_question(q_data, field_index, seen_fields, section_title, subsection_title)
        field_id = q_data[:field_id]
        location = "#{section_title}, #{subsection_title}"

        # Check for duplicates
        if seen_fields[field_id]
          raise DuplicateFieldError.new(field_id, location)
        end
        seen_fields[field_id] = true

        # Lookup field
        field = field_index[field_id]
        raise UnknownFieldError, field_id unless field

        AmsfSurvey::Question.new(
          number: q_data[:number],
          field: field,
          instructions: q_data[:instructions]
        )
      end
    end
  end
end
