# frozen_string_literal: true

module AmsfSurvey
  # Represents a logical grouping of questions within a section (e.g., "1.1", "1.2").
  # Immutable value object built by the taxonomy loader.
  class Subsection
    include LocaleSupport

    attr_reader :number, :questions

    def initialize(number:, title:, questions:, instructions: nil)
      @number = number
      @titles = normalize_locale_hash(title)
      @instructions_map = normalize_locale_hash(instructions)
      @questions = questions
    end

    # Returns subsection title for the given locale, with fallback
    def title(locale = AmsfSurvey.locale)
      resolve_locale(@titles, locale)
    end

    # Returns subsection instructions for the given locale, with fallback
    def instructions(locale = AmsfSurvey.locale)
      resolve_locale(@instructions_map, locale)
    end

    def question_count
      questions.length
    end

    def empty?
      questions.empty?
    end
  end
end
