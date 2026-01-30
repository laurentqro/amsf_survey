# frozen_string_literal: true

module AmsfSurvey
  # Represents a logical grouping of questions within a section (e.g., "1.1", "1.2").
  # Immutable value object built by the taxonomy loader.
  class Subsection
    attr_reader :number, :title, :instructions, :questions

    def initialize(number:, title:, questions:, instructions: nil)
      @number = number
      @title = title
      @instructions = instructions
      @questions = questions
    end

    def question_count
      questions.length
    end

    def empty?
      questions.empty?
    end
  end
end
