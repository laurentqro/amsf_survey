# frozen_string_literal: true

module AmsfSurvey
  # Container for survey response data.
  # Holds entity_id, period, industry, year, and a hash of field values.
  # Provides access to the questionnaire and tracks completeness.
  class Submission
    attr_reader :industry, :year, :entity_id, :period

    # Create a new submission for a specific industry and year.
    #
    # @param industry [Symbol] registered industry (e.g., :real_estate)
    # @param year [Integer] taxonomy year (e.g., 2025)
    # @param entity_id [String] unique identifier for the reporting entity
    # @param period [Date] reporting period end date
    def initialize(industry:, year:, entity_id:, period:)
      @industry = industry
      @year = year
      @entity_id = entity_id
      @period = period
      @data = {}
    end

    # Get the questionnaire associated with this submission's industry and year.
    # Cached for performance.
    #
    # @return [Questionnaire] the questionnaire
    def questionnaire
      @questionnaire ||= AmsfSurvey.questionnaire(industry: industry, year: year)
    end

    # Get a field value by semantic name.
    #
    # @param field_id [Symbol] the field identifier
    # @return [Object, nil] the stored value or nil
    # @raise [UnknownFieldError] if field doesn't exist in questionnaire
    def [](field_id)
      field_id = field_id.to_sym
      validate_field!(field_id)
      @data[field_id]
    end

    # Set a field value by semantic name.
    # Value is automatically type-cast based on field definition.
    #
    # @param field_id [Symbol] the field identifier
    # @param value [Object] the value to set (will be type-cast)
    # @raise [UnknownFieldError] if field doesn't exist in questionnaire
    def []=(field_id, value)
      field_id = field_id.to_sym
      field = validate_field!(field_id)
      @data[field_id] = field.cast(value)
    end

    # Get a frozen copy of the data hash (for inspection/serialization).
    # Returns a defensive copy to prevent external mutation.
    #
    # @return [Hash{Symbol => Object}] frozen field values keyed by semantic field ID
    def data
      @data.dup.freeze
    end

    # Check if all required visible fields are filled.
    #
    # @return [Boolean] true if submission is complete
    def complete?
      missing_fields.empty?
    end

    # Get list of required visible fields that are not filled.
    # Respects gate visibility - hidden fields are not considered missing.
    #
    # @return [Array<Symbol>] missing field IDs
    def missing_fields
      required_visible_fields.select { |field| field_missing?(field) }
                             .map(&:id)
    end

    # Calculate completion percentage based on required visible fields.
    #
    # @return [Float] percentage from 0.0 to 100.0
    def completion_percentage
      required = required_visible_fields
      return 100.0 if required.empty?

      filled = required.count { |field| !field_missing?(field) }
      (filled.to_f / required.size * 100).round(1)
    end

    # Get list of entry-only fields that are missing.
    # Entry-only fields require fresh user input (not prefillable or computed).
    #
    # @return [Array<Symbol>] missing entry-only field IDs
    def missing_entry_only_fields
      required_visible_fields.select { |field| field.entry_only? && field_missing?(field) }
                             .map(&:id)
    end

    # Internal data access for validation.
    # @api private
    # @return [Hash{Symbol => Object}] raw data hash reference
    def internal_data
      @data
    end

    private

    # Validate that a field exists in the questionnaire.
    # @param field_id [Symbol] the field identifier
    # @return [Field] the field if found
    # @raise [UnknownFieldError] if field doesn't exist
    def validate_field!(field_id)
      field = questionnaire.field(field_id)
      raise UnknownFieldError, field_id unless field

      field
    end

    # Get all required visible fields.
    # Required = not computed
    # Visible = gate dependencies satisfied
    def required_visible_fields
      questionnaire.fields.select do |field|
        field.required? && field.visible?(@data)
      end
    end

    # Check if a field value is missing (nil or not set).
    def field_missing?(field)
      !@data.key?(field.id) || @data[field.id].nil?
    end
  end
end
