# frozen_string_literal: true

module AmsfSurvey
  # Represents a single survey question with all metadata.
  # Immutable value object built by the taxonomy loader.
  class Field
    attr_reader :xbrl_id, :type, :xbrl_type, :label,
                :verbose_label, :valid_values, :section_id, :order,
                :depends_on, :gate, :min, :max

    def initialize(
      id:,
      type:,
      xbrl_type:,
      label:,
      section_id:,
      order:,
      gate:,
      verbose_label: nil,
      valid_values: nil,
      depends_on: {},
      min: nil,
      max: nil
    )
      @xbrl_id = id
      @id = id.to_s.downcase.to_sym
      @type = type
      @xbrl_type = xbrl_type
      @label = label
      @section_id = section_id
      @order = order
      @gate = gate
      @verbose_label = verbose_label
      @valid_values = valid_values
      @depends_on = depends_on || {}
      @min = min
      @max = max
    end

    # Returns lowercase ID for API usage (e.g., :aactive, :a1101)
    def id
      @id
    end

    # Check if this field has range constraints.
    def has_range?
      !@min.nil? || !@max.nil?
    end

    # Type predicates
    def boolean? = type == :boolean
    def integer? = type == :integer
    def string? = type == :string
    def monetary? = type == :monetary
    def enum? = type == :enum
    def percentage? = type == :percentage

    # Gate predicates
    def gate? = gate

    # Cast a value to the appropriate type for this field.
    # Delegates to TypeCaster based on field type.
    #
    # @param value [Object] the value to cast
    # @return [Object, nil] the cast value
    def cast(value)
      TypeCaster.cast(value, type)
    end

    # Sentinel value for missing/unanswered gate questions.
    # Using a unique object ensures no collision with actual user values.
    NOT_ANSWERED = Object.new.freeze
    private_constant :NOT_ANSWERED

    # Evaluates gate dependencies against submission data.
    # Returns true if all dependencies are satisfied or if there are no dependencies.
    #
    # @param data [Hash{Symbol => String}] submission data with symbol keys
    # @return [Boolean] true if field should be visible
    #
    # @note Data hash must use symbol keys (e.g., { tGATE: "Oui" }).
    #   String keys will not match dependencies.
    # @note Missing keys and nil values are treated as "not satisfied".
    #   A gate requiring "Oui" will return false if the key is missing or nil.
    #   This is intentional: unanswered gates hide dependent fields.
    #
    # @example Basic usage
    #   field.visible?({ tGATE: "Oui" })  # => true if depends_on[:tGATE] == "Oui"
    #
    # @example Missing gate value
    #   field.visible?({})                # => false (unanswered gate hides field)
    #   field.visible?({ tGATE: nil })    # => false (nil treated as unanswered)
    #
    def visible?(data)
      return true if depends_on.empty?

      depends_on.all? do |gate_id, required_value|
        # fetch with sentinel makes nil-handling explicit:
        # - Missing key -> NOT_ANSWERED (never equals required_value)
        # - nil value -> nil (never equals required_value like "Oui")
        actual_value = data.fetch(gate_id, NOT_ANSWERED)
        actual_value == required_value
      end
    end
  end
end
