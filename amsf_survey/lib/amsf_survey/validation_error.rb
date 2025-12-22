# frozen_string_literal: true

module AmsfSurvey
  # Represents a single validation issue with full context for debugging and display.
  # Immutable value object.
  class ValidationError
    attr_reader :field, :rule, :message, :severity, :context

    # Create a new validation error.
    #
    # @param field [Symbol] field ID where error occurred
    # @param rule [Symbol] rule type that failed (:presence, :range, :enum, :conditional)
    # @param message [String] human-readable error message
    # @param severity [Symbol] :error or :warning
    # @param context [Hash] rule-specific details (e.g., expected:, actual:, min:, max:)
    def initialize(field:, rule:, message:, severity:, context: {})
      @field = field
      @rule = rule
      @message = message
      @severity = severity
      @context = context
    end

    # Check if this is a blocking error.
    def error?
      severity == :error
    end

    # Check if this is a non-blocking warning.
    def warning?
      severity == :warning
    end

    # Convert to hash for serialization.
    #
    # @return [Hash]
    def to_h
      {
        field: field,
        rule: rule,
        message: message,
        severity: severity,
        context: context
      }
    end

    # Format as string for display.
    #
    # @return [String]
    def to_s
      "[#{severity}] #{field}: #{message}"
    end
  end
end
