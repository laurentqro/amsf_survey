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

    # Evaluates gate dependencies against internal submission data.
    # Used by Submission#visible_fields - not part of public API.
    # Data hash must use original XBRL ID keys to match depends_on.
    def visible?(data)
      return true if depends_on.empty?

      depends_on.all? do |gate_id, required_value|
        data.key?(gate_id) && data[gate_id] == required_value
      end
    end

    private :visible?
  end
end
