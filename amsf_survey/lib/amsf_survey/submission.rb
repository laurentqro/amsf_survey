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

    # Get a field value by lowercase field ID.
    # Input is normalized to lowercase for consistent lookup.
    #
    # @param field_id [Symbol, String] the field identifier
    # @return [Object, nil] the stored value or nil
    # @raise [UnknownFieldError] if field doesn't exist in questionnaire
    def [](field_id)
      field_id = normalize_field_id(field_id)
      validate_field!(field_id)
      @data[field_id]
    end

    # Set a field value by lowercase field ID.
    # Input is normalized to lowercase. Value is automatically type-cast.
    #
    # @param field_id [Symbol, String] the field identifier
    # @param value [Object] the value to set (will be type-cast)
    # @raise [UnknownFieldError] if field doesn't exist in questionnaire
    def []=(field_id, value)
      field_id = normalize_field_id(field_id)
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

    # Calculate completion percentage based on visible fields.
    #
    # @return [Float] percentage from 0.0 to 100.0
    def completion_percentage
      visible = visible_fields
      return 100.0 if visible.empty?

      filled = visible.count { |field| !field_missing?(field) }
      (filled.to_f / visible.size * 100).round(1)
    end

    private

    # Internal data access for validation.
    # @api private
    # @return [Hash{Symbol => Object}] raw data hash reference
    def internal_data
      @data
    end

    # Normalize field ID to lowercase symbol for consistent lookup.
    # @param field_id [Symbol, String] the field identifier
    # @return [Symbol] lowercase field ID
    def normalize_field_id(field_id)
      field_id.to_s.downcase.to_sym
    end

    # Validate that a field exists in the questionnaire.
    # @param field_id [Symbol] the field identifier
    # @return [Field] the field if found
    # @raise [UnknownFieldError] if field doesn't exist
    def validate_field!(field_id)
      field = questionnaire.field(field_id)
      raise UnknownFieldError, field_id unless field

      field
    end

    # Alias for visible_fields (backwards compatibility during transition)
    def required_visible_fields
      visible_fields
    end

    # Get all visible fields (gate dependencies satisfied).
    # All visible fields are required by law for obligated entities.
    def visible_fields
      questionnaire.fields.select { |field| field.visible?(@data) }
    end

    # Check if a field value is missing (nil or not set).
    def field_missing?(field)
      !@data.key?(field.id) || @data[field.id].nil?
    end
  end
end
