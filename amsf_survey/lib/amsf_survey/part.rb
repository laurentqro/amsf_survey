# frozen_string_literal: true

module AmsfSurvey
  # Represents a top-level part from the PDF (e.g., "Inherent Risk", "Controls", "Signatories").
  # Contains sections. Question numbers reset within each part.
  # Immutable value object built by the taxonomy loader.
  class Part
    include LocaleSupport

    attr_reader :sections

    def initialize(name:, sections:)
      @names = normalize_locale_hash(name)
      @sections = sections
    end

    # Returns part name for the given locale, with fallback
    def name(locale = AmsfSurvey.locale)
      resolve_locale(@names, locale)
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
