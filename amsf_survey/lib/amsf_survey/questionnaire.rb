# frozen_string_literal: true

module AmsfSurvey
  # Container for an industry/year survey structure.
  # Immutable value object built by the taxonomy loader.
  class Questionnaire
    attr_reader :industry, :year, :sections, :taxonomy_namespace

    def initialize(industry:, year:, sections:, taxonomy_namespace: nil)
      @industry = industry
      @year = year
      @sections = sections
      @taxonomy_namespace = taxonomy_namespace
      @field_index = build_field_index
    end

    # Returns all questions from all sections in order
    def questions
      sections.flat_map(&:questions)
    end

    # Returns all fields across all sections in order
    # Extracts the Field from each Question in the hierarchy
    def fields
      questions.map(&:field)
    end

    # Lookup field by lowercase ID
    # Input is normalized to lowercase for consistent lookup
    def field(id)
      @field_index[id.to_s.downcase.to_sym]
    end

    # Total number of questions
    def question_count
      questions.length
    end

    # Total number of fields (alias for question_count)
    def field_count
      question_count
    end

    # Number of sections
    def section_count
      sections.length
    end

    # Fields where gate is true
    def gate_fields
      fields.select(&:gate?)
    end

    private

    def build_field_index
      fields.each_with_object({}) do |field, index|
        index[field.id] = field
      end
    end
  end
end
