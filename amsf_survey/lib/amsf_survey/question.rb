# frozen_string_literal: true

module AmsfSurvey
  # Wraps a Field with PDF-sourced metadata (question number, instructions).
  # Delegates XBRL attributes to the underlying Field.
  #
  # Public API exposes all attributes directly - Field is an internal detail.
  class Question
    attr_reader :number, :instructions

    def initialize(number:, field:, instructions:)
      @number = number
      @field = field
      @instructions = instructions
    end

    # Delegate XBRL attributes to field
    def id = field.id
    def xbrl_id = field.xbrl_id
    def xbrl_type = field.xbrl_type
    def label = field.label
    def verbose_label = field.verbose_label
    def type = field.type
    def valid_values = field.valid_values
    def gate? = field.gate?
    def depends_on = field.depends_on
    def dimensional? = field.dimensional?

    # Cast a value to the appropriate type for this question
    def cast(value) = field.cast(value)

    # Evaluate visibility based on gate dependencies
    def visible?(data)
      field.send(:visible?, data)
    end

    protected

    # Internal: access to underlying Field for Generator and Submission
    attr_reader :field
  end
end
