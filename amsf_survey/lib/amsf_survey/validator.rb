# frozen_string_literal: true

module AmsfSurvey
  # Orchestrates validation of a submission against all applicable rules.
  # Checks presence, enum values, ranges, and conditional requirements.
  module Validator
    module_function

    # Validate a submission and return structured results.
    #
    # @param submission [Submission] the submission to validate
    # @return [ValidationResult] validation outcome with errors and warnings
    def validate(submission)
      errors = []
      warnings = []

      # Collect all validation errors
      errors.concat(validate_presence(submission))
      errors.concat(validate_enums(submission))
      errors.concat(validate_ranges(submission))

      ValidationResult.new(errors: errors, warnings: warnings)
    end

    # Validate required fields are present.
    #
    # @param submission [Submission]
    # @return [Array<ValidationError>]
    def validate_presence(submission)
      errors = []
      data = submission.internal_data

      submission.questionnaire.fields.each do |field|
        next unless field.required? && field.visible?(data)
        next if data.key?(field.id) && !data[field.id].nil?

        errors << ValidationError.new(
          field: field.id,
          rule: :presence,
          message: "Field '#{field.label}' is required",
          severity: :error
        )
      end

      errors
    end

    # Validate enum fields have valid values.
    #
    # @param submission [Submission]
    # @return [Array<ValidationError>]
    def validate_enums(submission)
      errors = []
      data = submission.internal_data

      submission.questionnaire.fields.each do |field|
        next unless field.valid_values && !field.valid_values.empty?
        next unless field.visible?(data)

        value = data[field.id]
        next if value.nil? # Presence check handles missing values

        unless field.valid_values.include?(value)
          errors << ValidationError.new(
            field: field.id,
            rule: :enum,
            message: "Field '#{field.label}' must be one of: #{field.valid_values.join(', ')}",
            severity: :error,
            context: { value: value, valid_values: field.valid_values }
          )
        end
      end

      errors
    end

    # Validate fields with range constraints (percentage fields).
    # Currently validates fields with "percentage" in their name as 0-100.
    #
    # @param submission [Submission]
    # @return [Array<ValidationError>]
    def validate_ranges(submission)
      errors = []
      data = submission.internal_data

      submission.questionnaire.fields.each do |field|
        next unless field.visible?(data)
        next unless is_percentage_field?(field)

        value = data[field.id]
        next if value.nil?

        if value < 0
          errors << ValidationError.new(
            field: field.id,
            rule: :range,
            message: "Field '#{field.label}' must be at least 0",
            severity: :error,
            context: { value: value, min: 0, max: 100 }
          )
        elsif value > 100
          errors << ValidationError.new(
            field: field.id,
            rule: :range,
            message: "Field '#{field.label}' must be at most 100",
            severity: :error,
            context: { value: value, min: 0, max: 100 }
          )
        end
      end

      errors
    end

    # Check if field is a percentage field (heuristic based on name).
    # In the future, this could be driven by taxonomy metadata.
    def is_percentage_field?(field)
      field.id.to_s.include?("percentage") || field.name.to_s.include?("percentage")
    end
  end
end
