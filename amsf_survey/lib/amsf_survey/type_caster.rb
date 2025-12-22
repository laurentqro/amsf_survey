# frozen_string_literal: true

require "bigdecimal"

module AmsfSurvey
  # Converts string inputs to appropriate Ruby types based on field type.
  # Used by Submission when setting field values to ensure data integrity.
  module TypeCaster
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
    def cast_integer(value)
      return value if value.is_a?(Integer)

      str = value.to_s.strip
      return nil if str.empty?
      return nil unless str.match?(/\A-?\d+\z/)

      str.to_i
    end

    # Cast to BigDecimal for monetary precision.
    # Returns nil for empty or non-numeric strings.
    def cast_monetary(value)
      return value if value.is_a?(BigDecimal)
      return nil if value.nil?

      str = value.to_s.strip
      return nil if str.empty?

      BigDecimal(str)
    rescue ArgumentError
      nil
    end

    # Boolean fields preserve string values ("Oui"/"Non").
    # Validation handles checking if the value is valid.
    def cast_boolean(value)
      return nil if value.nil?

      value.to_s
    end

    # Enum fields preserve string values.
    # Validation handles checking if the value is in valid_values.
    def cast_enum(value)
      return nil if value.nil?

      value.to_s
    end

    # String fields convert to string via to_s.
    def cast_string(value)
      return nil if value.nil?

      value.to_s
    end
  end
end
