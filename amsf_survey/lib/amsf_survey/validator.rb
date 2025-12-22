# frozen_string_literal: true

module AmsfSurvey
  # Orchestrates validation of a submission against all applicable rules.
  # Checks presence, enum values, ranges, and conditional requirements.
  #
  # Uses a single-pass approach for efficiency: each field is visited once
  # and all applicable validations are run during that visit.
  module Validator
    module_function

    # Validate a submission and return structured results.
    #
    # @param submission [Submission] the submission to validate
    # @return [ValidationResult] validation outcome with errors and warnings
    def validate(submission)
      errors = []
      warnings = []
      data = submission.internal_data

      # Single pass through all fields for efficiency
      submission.questionnaire.fields.each do |field|
        next unless field.visible?(data)

        value = data[field.id]

        # Run all validations for this field
        errors.concat(validate_field_presence(field, value))
        errors.concat(validate_field_enum(field, value))
        errors.concat(validate_field_range(field, value))
      end

      ValidationResult.new(errors: errors, warnings: warnings)
    end

    # Validate presence for a single field.
    #
    # @param field [Field] the field to validate
    # @param value [Object, nil] the current value
    # @return [Array<ValidationError>]
    def validate_field_presence(field, value)
      return [] unless field.required?
      return [] unless value.nil?

      [ValidationError.new(
        field: field.id,
        rule: :presence,
        message: I18n.t("amsf_survey.validation.presence", field: field.label),
        severity: :error
      )]
    end

    # Validate enum value for a single field.
    #
    # @param field [Field] the field to validate
    # @param value [Object, nil] the current value
    # @return [Array<ValidationError>]
    def validate_field_enum(field, value)
      return [] unless field.valid_values && !field.valid_values.empty?
      return [] if value.nil? # Presence check handles missing values

      return [] if field.valid_values.include?(value)

      [ValidationError.new(
        field: field.id,
        rule: :enum,
        message: I18n.t("amsf_survey.validation.enum", field: field.label, valid_values: field.valid_values.join(", ")),
        severity: :error,
        context: { value: value, valid_values: field.valid_values }
      )]
    end

    # Validate range constraints for a single field.
    #
    # @param field [Field] the field to validate
    # @param value [Object, nil] the current value
    # @return [Array<ValidationError>]
    def validate_field_range(field, value)
      min, max = range_for_field(field)
      return [] if min.nil? && max.nil?
      return [] if value.nil?

      if min && value < min
        [ValidationError.new(
          field: field.id,
          rule: :range,
          message: I18n.t("amsf_survey.validation.range_min", field: field.label, min: min),
          severity: :error,
          context: { value: value, min: min, max: max }
        )]
      elsif max && value > max
        [ValidationError.new(
          field: field.id,
          rule: :range,
          message: I18n.t("amsf_survey.validation.range_max", field: field.label, max: max),
          severity: :error,
          context: { value: value, min: min, max: max }
        )]
      else
        []
      end
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
