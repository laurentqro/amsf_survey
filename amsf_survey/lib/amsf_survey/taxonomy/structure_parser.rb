# frozen_string_literal: true

require "yaml"

module AmsfSurvey
  module Taxonomy
    # Parses questionnaire_structure.yml to extract PDF-based structure.
    # Supports parts-based format: Part -> Section -> Subsection -> Question
    class StructureParser
      def initialize(structure_path)
        @structure_path = structure_path
      end

      def parse
        validate_file!
        data = load_yaml

        parts = parse_parts(data["parts"] || [])
        { parts: parts }
      end

      private

      def validate_file!
        return if File.exist?(@structure_path)

        raise MissingStructureFileError, @structure_path
      end

      def load_yaml
        YAML.safe_load(File.read(@structure_path), permitted_classes: [], permitted_symbols: [], aliases: false)
      rescue Psych::SyntaxError => e
        raise MalformedTaxonomyError.new(@structure_path, e.message)
      end

      def parse_parts(parts_data)
        parts_data.map do |part_data|
          parse_part(part_data)
        end
      end

      def parse_part(part_data)
        sections = (part_data["sections"] || []).map do |section_data|
          parse_section(section_data)
        end

        {
          name: part_data["name"],
          sections: sections
        }
      end

      def parse_section(section_data)
        subsections = (section_data["subsections"] || []).map do |sub_data|
          parse_subsection(sub_data)
        end

        {
          number: section_data["number"],
          title: section_data["title"],
          subsections: subsections
        }
      end

      def parse_subsection(sub_data)
        questions = (sub_data["questions"] || []).map do |q_data|
          parse_question(q_data)
        end

        {
          number: sub_data["number"],
          title: sub_data["title"],
          instructions: clean_instructions(sub_data["instructions"]),
          questions: questions
        }
      end

      def parse_question(q_data)
        {
          number: q_data["question_number"],
          field_id: q_data["field_id"].to_s.downcase.to_sym,
          instructions: clean_instructions(q_data["instructions"])
        }
      end

      def clean_instructions(value)
        case value
        when Hash
          cleaned = value.transform_values { |v| v&.strip }
          cleaned.values.all? { |v| v.nil? || v.empty? } ? nil : cleaned
        when String
          stripped = value.strip
          stripped.empty? ? nil : stripped
        end
      end
    end
  end
end
