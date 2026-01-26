# frozen_string_literal: true

require "yaml"

module AmsfSurvey
  module Taxonomy
    # Parses questionnaire_structure.yml to extract PDF-based structure.
    class StructureParser
      def initialize(structure_path)
        @structure_path = structure_path
      end

      def parse
        validate_file!
        data = load_yaml

        sections = parse_sections(data["sections"] || [])
        { sections: sections }
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

      def parse_sections(sections_data)
        sections_data.each_with_index.map do |section_data, index|
          parse_section(section_data, index + 1)
        end
      end

      def parse_section(section_data, section_number)
        question_counter = 0
        subsections = (section_data["subsections"] || []).each_with_index.map do |sub_data, index|
          subsection, question_counter = parse_subsection(sub_data, index + 1, question_counter)
          subsection
        end

        {
          number: section_number,
          title: section_data["title"],
          subsections: subsections
        }
      end

      def parse_subsection(sub_data, subsection_number, question_counter)
        questions = (sub_data["questions"] || []).map do |q_data|
          question_counter += 1
          parse_question(q_data, question_counter)
        end

        subsection = {
          number: subsection_number,
          title: sub_data["title"],
          questions: questions
        }

        [subsection, question_counter]
      end

      def parse_question(q_data, question_number)
        instructions = q_data["instructions"]&.strip
        instructions = nil if instructions&.empty?

        {
          number: question_number,
          field_id: q_data["field_id"].to_s.downcase.to_sym,
          instructions: instructions
        }
      end
    end
  end
end
