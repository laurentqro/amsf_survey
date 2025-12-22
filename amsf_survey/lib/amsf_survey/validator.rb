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

    # Validate fields with range constraints.
    # Uses Field#min and Field#max when available, with fallback heuristic
    # for percentage fields (0-100) until taxonomy provides range metadata.
    #
    # @param submission [Submission]
    # @return [Array<ValidationError>]
    def validate_ranges(submission)
      errors = []
      data = submission.internal_data

      submission.questionnaire.fields.each do |field|
        next unless field.visible?(data)

        min, max = range_for_field(field)
        next if min.nil? && max.nil?

        value = data[field.id]
        next if value.nil?

        if min && value < min
          errors << ValidationError.new(
            field: field.id,
            rule: :range,
            message: "Field '#{field.label}' must be at least #{min}",
            severity: :error,
            context: { value: value, min: min, max: max }
          )
        elsif max && value > max
          errors << ValidationError.new(
            field: field.id,
            rule: :range,
            message: "Field '#{field.label}' must be at most #{max}",
            severity: :error,
            context: { value: value, min: min, max: max }
          )
        end
      end

      errors
    end

    # Get range constraints for a field.
    # Prefers explicit Field#min/max, falls back to heuristic for percentage fields.
    #
    # @param field [Field]
    # @return [Array(Integer, Integer), Array(nil, nil)] [min, max] or [nil, nil]
    def range_for_field(field)
      # Use explicit range metadata if available
      return [field.min, field.max] if field.has_range?

      # Fallback heuristic: percentage fields are 0-100
      # TODO: Remove once taxonomy provides range metadata
      if percentage_field_heuristic?(field)
        [0, 100]
      else
        [nil, nil]
      end
    end

    # Heuristic: detect percentage fields by name.
    # @deprecated Use Field#min/max instead when available from taxonomy.
    def percentage_field_heuristic?(field)
      field.id.to_s.include?("percentage") || field.name.to_s.include?("percentage")
    end
  end
end
