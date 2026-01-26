# frozen_string_literal: true

module AmsfSurvey
  # Represents a top-level section from the PDF structure (e.g., "Inherent Risk").
  # Contains subsections which contain questions.
  # Immutable value object built by the taxonomy loader.
  class Section
    attr_reader :number, :title, :subsections

    def initialize(number:, title:, subsections:)
      @number = number
      @title = title
      @subsections = subsections
    end

    # Returns all questions from all subsections in order
    def questions
      subsections.flat_map(&:questions)
    end

    # Total number of questions across all subsections
    def question_count
      questions.length
    end

    # Number of subsections
    def subsection_count
      subsections.length
    end

    # Returns true if section has no subsections
    def empty?
      subsections.empty?
    end
  end
end
