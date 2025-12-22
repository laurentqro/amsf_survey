# frozen_string_literal: true

module AmsfSurvey
  # Represents a single survey question with all metadata.
  # Immutable value object built by the taxonomy loader.
  class Field
    attr_reader :id, :name, :type, :xbrl_type, :source_type, :label,
                :verbose_label, :valid_values, :section_id, :order,
                :depends_on, :gate

    def initialize(
      id:,
      name:,
      type:,
      xbrl_type:,
      source_type:,
      label:,
      section_id:,
      order:,
      gate:,
      verbose_label: nil,
      valid_values: nil,
      depends_on: {}
    )
      @id = id
      @name = name
      @type = type
      @xbrl_type = xbrl_type
      @source_type = source_type
      @label = label
      @section_id = section_id
      @order = order
      @gate = gate
      @verbose_label = verbose_label
      @valid_values = valid_values
      @depends_on = depends_on || {}
    end

    # Type predicates
    def boolean? = type == :boolean
    def integer? = type == :integer
    def string? = type == :string
    def monetary? = type == :monetary
    def enum? = type == :enum

    # Source type predicates
    def computed? = source_type == :computed
    def prefillable? = source_type == :prefillable
    def entry_only? = source_type == :entry_only

    # Gate predicates
    def gate? = gate

    # Returns true if this field requires user input when visible.
    # Computed fields are never required (values derived automatically).
    def required?
      !computed?
    end

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
    def visible?(data)
      return true if depends_on.empty?

      depends_on.all? do |gate_id, required_value|
        data[gate_id] == required_value
      end
    end
  end
end
