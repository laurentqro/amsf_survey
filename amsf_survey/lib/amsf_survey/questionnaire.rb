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
      @question_index = build_question_index
    end

    # Returns all questions from all sections in order
    def questions
      sections.flat_map(&:questions)
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
