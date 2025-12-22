# frozen_string_literal: true

require "bigdecimal"

module AmsfSurvey
  # Converts string inputs to appropriate Ruby types based on field type.
  # Used by Submission when setting field values to ensure data integrity.
  #
  # ## Error Handling Strategy
  #
  # Invalid inputs return nil rather than raising exceptions. This design choice:
  # - Enables graceful handling of user input errors
  # - Allows validation layer to report structured errors
  # - Prevents data entry from failing catastrophically
  #
  # For regulatory submissions requiring strict mode, the Validator layer
  # catches nil values via presence validation and reports them as errors.
  # The audit trail is maintained in ValidationResult, not here.
  #
  # @see Validator For presence and range validation of cast values
  # @see ValidationResult For structured error reporting with audit context
  module TypeCaster
    # Maximum input length for defense-in-depth against DoS.
    # Regulatory monetary values rarely exceed 20 digits.
    MAX_INPUT_LENGTH = 100

    module_function

    # Cast a value to the appropriate type based on field type.
    #
    # @param value [Object] the value to cast
    # @param field_type [Symbol] the field type (:integer, :monetary, :boolean, :enum, :string)
    # @return [Object, nil] the cast value, or nil for empty/invalid values
    def cast(value, field_type)
      return nil if value.nil?

      case field_type
      when :integer
        cast_integer(value)
      when :monetary
        cast_monetary(value)
      when :boolean
        cast_boolean(value)
      when :enum
        cast_enum(value)
      when :string
        cast_string(value)
      else
        value
      end
    end

    # Cast to integer. Returns nil for empty, whitespace-only, or non-numeric strings.
    # Also rejects inputs exceeding MAX_INPUT_LENGTH for DoS protection.
    def cast_integer(value)
      return value if value.is_a?(Integer)

      str = value.to_s.strip
      return nil if str.empty?
      return nil if str.length > MAX_INPUT_LENGTH
      return nil unless str.match?(/\A-?\d+\z/)

      str.to_i
    end

    # Cast to BigDecimal for monetary precision.
    # Returns nil for empty, non-numeric, or excessively long strings.
    # Catches ArgumentError and FloatDomainError for malformed inputs.
    def cast_monetary(value)
      return value if value.is_a?(BigDecimal)
      return nil if value.nil?

      str = value.to_s.strip
      return nil if str.empty?
      return nil if str.length > MAX_INPUT_LENGTH

      BigDecimal(str)
    rescue ArgumentError, FloatDomainError
      nil
    end

    # Boolean fields preserve string values ("Oui"/"Non").
    # Returns nil for empty strings for consistency with other types.
    # Validation handles checking if the value is valid.
    def cast_boolean(value)
      return nil if value.nil?

      str = value.to_s.strip
      str.empty? ? nil : str
    end

    # Enum fields preserve string values.
    # Returns nil for empty strings for consistency with other types.
    # Validation handles checking if the value is in valid_values.
    def cast_enum(value)
      return nil if value.nil?

      str = value.to_s.strip
      str.empty? ? nil : str
    end

    # String fields convert to string via to_s.
    # Returns nil for empty strings for consistency with other types.
    def cast_string(value)
      return nil if value.nil?

      str = value.to_s.strip
      str.empty? ? nil : str
    end
  end
end
