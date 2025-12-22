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
    # @param locale [Symbol] locale for error messages (default: AmsfSurvey::DEFAULT_LOCALE)
    # @return [ValidationResult] validation outcome with errors and warnings
    def validate(submission, locale: AmsfSurvey::DEFAULT_LOCALE)
      I18n.with_locale(locale) do
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

      # Type safety: only compare if value is Numeric
      # TypeCaster should ensure this, but guard against edge cases
      return [] unless value.is_a?(Numeric)

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
    #
    # Resolution order:
    # 1. Explicit Field#min/max from taxonomy (preferred)
    # 2. Field#percentage? type (if taxonomy uses :percentage type)
    # 3. Name-based heuristic (temporary fallback)
    #
    # @param field [Field]
    # @return [Array(Integer, Integer), Array(nil, nil)] [min, max] or [nil, nil]
    def range_for_field(field)
      # Priority 1: Explicit range metadata from taxonomy
      return [field.min, field.max] if field.has_range?

      # Priority 2: Formal percentage type
      return [0, 100] if field.percentage?

      # Priority 3: Name-based heuristic (temporary)
      return [0, 100] if percentage_name_heuristic?(field)

      [nil, nil]
    end

    # Temporary heuristic: detect percentage fields by name pattern.
    #
    # @deprecated This heuristic exists only for backwards compatibility with
    #   taxonomies that don't yet provide Field#min/max or use :percentage type.
    #   Remove once all taxonomies specify range constraints explicitly.
    #
    # @note This approach is fragile because it:
    #   - Depends on English naming conventions
    #   - Won't work for internationalized field names
    #   - May false-positive on unrelated fields containing "percentage"
    #
    # @param field [Field]
    # @return [Boolean]
    def percentage_name_heuristic?(field)
      field.id.to_s.include?("percentage") || field.name.to_s.include?("percentage")
    end
  end
end
