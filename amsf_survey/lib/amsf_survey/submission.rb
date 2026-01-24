# frozen_string_literal: true

module AmsfSurvey
  # Container for survey response data.
  # Holds entity_id, period, industry, year, and a hash of field values.
  # Provides access to the questionnaire and tracks completeness.
  #
  # Public API uses lowercase field IDs for convenience.
  # Internal storage uses original XBRL IDs for consistency with taxonomy.
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
      @data = {}  # Keyed by original XBRL ID (e.g., :tGATE, :a1101)
    end

    # Get the questionnaire associated with this submission's industry and year.
    # Cached for performance.
    #
    # @return [Questionnaire] the questionnaire
    def questionnaire
      @questionnaire ||= AmsfSurvey.questionnaire(industry: industry, year: year)
    end

    # Get a field value by field ID.
    # Input is normalized to lowercase for public API convenience.
    #
    # @param field_id [Symbol, String] the field identifier (any casing)
    # @return [Object, nil] the stored value or nil
    # @raise [UnknownFieldError] if field doesn't exist in questionnaire
    def [](field_id)
      field = lookup_field(field_id)
      @data[field.xbrl_id]
    end

    # Set a field value by field ID.
    # Input is normalized to lowercase for public API convenience.
    # Value is automatically type-cast and stored with original XBRL ID.
    #
    # @param field_id [Symbol, String] the field identifier (any casing)
    # @param value [Object] the value to set (will be type-cast)
    # @raise [UnknownFieldError] if field doesn't exist in questionnaire
    def []=(field_id, value)
      field = lookup_field(field_id)
      @data[field.xbrl_id] = field.cast(value)
    end

    # Get a frozen copy of the data hash (for inspection/serialization).
    # Returns a defensive copy to prevent external mutation.
    # Keys are original XBRL IDs.
    #
    # @return [Hash{Symbol => Object}] frozen field values keyed by XBRL ID
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
    # Returns lowercase field IDs for public API consistency.
    #
    # @return [Array<Symbol>] missing field IDs (lowercase)
    def missing_fields
      visible_fields.select { |field| field_missing?(field) }
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

    # Lookup field by any casing, normalize via public API.
    # @param field_id [Symbol, String] the field identifier
    # @return [Field] the field if found
    # @raise [UnknownFieldError] if field doesn't exist
    def lookup_field(field_id)
      normalized_id = field_id.to_s.downcase.to_sym
      field = questionnaire.field(normalized_id)
      raise UnknownFieldError, field_id unless field

      field
    end

    # Get all visible fields (gate dependencies satisfied).
    # All visible fields are required by law for obligated entities.
    # Uses internal @data hash which has XBRL ID keys matching depends_on.
    def visible_fields
      questionnaire.fields.select { |field| field.visible?(@data) }
    end

    # Check if a field value is missing (nil or not set).
    # Uses xbrl_id for internal lookup since @data uses XBRL IDs.
    def field_missing?(field)
      !@data.key?(field.xbrl_id) || @data[field.xbrl_id].nil?
    end
  end
end
