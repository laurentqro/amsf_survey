# frozen_string_literal: true

module AmsfSurvey
  # Immutable outcome of validating a submission.
  # Separates errors (blocking) from warnings (informational).
  class ValidationResult
    attr_reader :errors, :warnings

    # Create a new validation result.
    #
    # @param errors [Array<ValidationError>] blocking validation issues
    # @param warnings [Array<ValidationError>] non-blocking issues
    def initialize(errors: [], warnings: [])
      @errors = errors.freeze
      @warnings = warnings.freeze
    end

    # Check if validation passed (no errors).
    #
    # @return [Boolean]
    def valid?
      errors.empty?
    end

    # Check if submission is complete (no missing required fields).
    # Looks for presence errors specifically.
    #
    # @return [Boolean]
    def complete?
      errors.none? { |e| e.rule == :presence }
    end

    # Count of blocking errors.
    #
    # @return [Integer]
    def error_count
      errors.size
    end

    # Count of non-blocking warnings.
    #
    # @return [Integer]
    def warning_count
      warnings.size
    end

    # Get errors for a specific field.
    #
    # @param field_id [Symbol] the field identifier
    # @return [Array<ValidationError>] errors for that field
    def errors_for(field_id)
      errors.select { |e| e.field == field_id }
    end
  end
end
