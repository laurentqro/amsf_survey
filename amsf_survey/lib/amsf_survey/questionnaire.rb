# frozen_string_literal: true

module AmsfSurvey
  # Container for an industry/year survey structure.
  # Immutable value object built by the taxonomy loader.
  class Questionnaire
    attr_reader :industry, :year, :parts, :taxonomy_namespace

    def initialize(industry:, year:, parts: nil, sections: nil, taxonomy_namespace: nil)
      @industry = industry
      @year = year
      @taxonomy_namespace = taxonomy_namespace

      # Support both parts-based and legacy sections-based initialization
      if parts
        @parts = parts
      elsif sections
        # Legacy: wrap sections in a single unnamed part for backward compatibility
        @parts = [Part.new(name: nil, sections: sections)]
      else
        @parts = []
      end

      @question_index = build_question_index
    end

    # Returns all sections from all parts (backward compatible)
    def sections
      parts.flat_map(&:sections)
    end

    # Returns all questions from all parts in order
    def questions
      parts.flat_map(&:questions)
    end

    # Lookup question by lowercase ID
    # Input is normalized to lowercase for consistent lookup
    #
    # @param id [Symbol, String] the field identifier (any casing)
    # @return [Question, nil] the question or nil if not found
    def question(id)
      @question_index[id.to_s.downcase.to_sym]
    end

    # Total number of questions
    def question_count
      questions.length
    end

    # Number of sections
    def section_count
      sections.length
    end

    # Number of parts
    def part_count
      parts.length
    end

    # Questions where gate is true
    def gate_questions
      questions.select(&:gate?)
    end

    private

    def build_question_index
      questions.each_with_object({}) do |question, index|
        index[question.id] = question
      end
    end
  end
end
