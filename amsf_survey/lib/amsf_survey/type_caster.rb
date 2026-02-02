# frozen_string_literal: true

require "bigdecimal"

module AmsfSurvey
  # Converts string inputs to appropriate Ruby types based on question type.
  # Used by Submission when setting question values to ensure data integrity.
  #
  # ## Error Handling Strategy
  #
  # Invalid inputs return nil rather than raising exceptions. This design choice:
  # - Enables graceful handling of user input errors
  # - Allows Submission#unanswered_questions to identify unfilled questions
  # - Prevents data entry from failing catastrophically
  #
  # For regulatory compliance, validation is delegated to Arelle (external XBRL validator).
  # The gem tracks completeness via Submission#complete? and Submission#unanswered_questions.
  #
  # ## Dimensional Fields (Country Breakdowns)
  #
  # Dimensional fields (integer, percentage, monetary) can accept Hash values for
  # country breakdowns:
  #   { "FR" => 40, "DE" => 30 }      # integer dimensional
  #   { "FR" => 40.0, "DE" => 30.0 }  # percentage dimensional
  #
  # Hash handling:
  # - Keys are normalized to uppercase strings (e.g., :fr → "FR")
  # - Values are cast to the appropriate type (Integer, BigDecimal, etc.)
  # - Empty hashes ({}) are treated as unanswered (equivalent to nil)
  # - Duplicate keys after normalization raise DuplicateKeyError
  #
  # @see Submission#complete? For checking if all visible questions are filled
  # @see Submission#unanswered_questions For listing unfilled visible questions
  module TypeCaster
    # Maximum input length for defense-in-depth against DoS.
    # Regulatory monetary values rarely exceed 20 digits.
    MAX_INPUT_LENGTH = 100

    module_function

    # Cast a value to the appropriate type based on field type.
    #
    # @param value [Object] the value to cast
    # @param field_type [Symbol] the field type (:integer, :monetary, :boolean, :enum, :string, :percentage)
    # @return [Object, nil] the cast value, or nil for empty/invalid values
    def cast(value, field_type)
      return nil if value.nil?

      case field_type
      when :integer
        cast_integer(value)
      when :monetary
        cast_monetary(value)
      when :percentage
        cast_percentage(value)
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

    # Cast to integer. Handles both scalar values and Hash values (for dimensional breakdowns).
    # Returns nil for empty, whitespace-only, or non-numeric strings.
    # Also rejects inputs exceeding MAX_INPUT_LENGTH for DoS protection.
    def cast_integer(value)
      return nil if value.nil?

      # Hash values for dimensional fields - normalize keys to uppercase
      return normalize_dimensional_hash(value, :cast_integer_scalar) if value.is_a?(Hash)

      cast_integer_scalar(value)
    end

    # Cast a single integer value.
    #
    # @param value [Object] the value to cast
    # @return [Integer, nil] the cast value
    def cast_integer_scalar(value)
      return value if value.is_a?(Integer)
      return nil if value.nil?

      str = value.to_s.strip
      return nil if str.empty?
      return nil if str.length > MAX_INPUT_LENGTH
      return nil unless str.match?(/\A-?\d+\z/)

      str.to_i
    end

    # Cast to BigDecimal for monetary precision. Handles both scalar values and
    # Hash values (for dimensional breakdowns).
    # Returns nil for empty, non-numeric, or excessively long strings.
    # Catches ArgumentError and FloatDomainError for malformed inputs.
    def cast_monetary(value)
      return nil if value.nil?

      # Hash values for dimensional fields - normalize keys to uppercase
      return normalize_dimensional_hash(value, :cast_monetary_scalar) if value.is_a?(Hash)

      cast_monetary_scalar(value)
    end

    # Cast a single monetary value to BigDecimal.
    #
    # @param value [Object] the value to cast
    # @return [BigDecimal, nil] the cast value
    def cast_monetary_scalar(value)
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

    # Percentage fields handle both scalar values and Hash values (for dimensional breakdowns).
    # Hash values have their keys normalized (uppercase country codes), scalar values are cast to BigDecimal.
    #
    # @param value [Object] the value to cast
    # @return [BigDecimal, Hash, nil] the cast value
    def cast_percentage(value)
      return nil if value.nil?

      # Hash values for dimensional fields - normalize keys to uppercase
      return normalize_dimensional_hash(value, :cast_percentage_scalar) if value.is_a?(Hash)

      cast_percentage_scalar(value)
    end

    # Normalize dimensional hash keys to uppercase strings.
    # Raises an error if duplicate keys are detected after normalization
    # (e.g., "fr" and "FR" would both normalize to "FR").
    # Casts each value using the specified scalar casting method.
    #
    # @param hash [Hash] country code => value mapping
    # @param scalar_caster [Symbol] method name for casting individual values
    # @return [Hash{String => Object}] normalized hash with cast values
    # @raise [DuplicateKeyError] if duplicate keys exist after normalization
    def normalize_dimensional_hash(hash, scalar_caster)
      result = {}
      hash.each do |key, value|
        normalized_key = key.to_s.upcase
        if result.key?(normalized_key)
          raise DuplicateKeyError, "Duplicate country code after normalization: " \
                                   "#{key.inspect} conflicts with existing key #{normalized_key}"
        end
        result[normalized_key] = send(scalar_caster, value)
      end
      result
    end

    # Cast a single percentage value to BigDecimal.
    #
    # @param value [Object] the value to cast
    # @return [BigDecimal, nil] the cast value
    def cast_percentage_scalar(value)
      return value if value.is_a?(BigDecimal)
      return nil if value.nil?

      str = value.to_s.strip
      return nil if str.empty?
      return nil if str.length > MAX_INPUT_LENGTH

      BigDecimal(str)
    rescue ArgumentError, FloatDomainError
      nil
    end
  end
end
