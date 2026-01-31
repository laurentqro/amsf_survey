# frozen_string_literal: true

module AmsfSurvey
  # Represents a top-level part from the PDF (e.g., "Inherent Risk", "Controls", "Signatories").
  # Contains sections. Question numbers reset within each part.
  # Immutable value object built by the taxonomy loader.
  class Part
    attr_reader :name, :sections

    def initialize(name:, sections:)
      @name = name
      @sections = sections
    end

    # Returns all questions from all sections in order
    def questions
      sections.flat_map(&:questions)
    end

    # Total number of questions across all sections
    def question_count
      questions.length
    end

    # Number of sections
    def section_count
      sections.length
    end

    # Returns true if part has no sections
    def empty?
      sections.empty?
    end
  end
end
