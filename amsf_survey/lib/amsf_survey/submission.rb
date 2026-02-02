# frozen_string_literal: true

module AmsfSurvey
  # Container for survey response data.
  # Holds entity_id, period, industry, year, and a hash of question values.
  # Provides access to the questionnaire and tracks completeness.
  #
  # Public API uses lowercase question IDs for convenience.
  # Internal storage uses original XBRL IDs for consistency with taxonomy.
  #
  # ## Dimensional Fields (Country Breakdowns)
  #
  # For dimensional questions (those requiring country breakdowns), values
  # should be provided as a Hash with country codes as keys:
  #
  #   submission[:a1204S1] = { "FR" => 40.0, "DE" => 30.0, "IT" => 30.0 }
  #
  # Country codes are automatically normalized to uppercase. An empty hash ({})
  # is treated as unanswered and will be excluded from XBRL generation when
  # include_empty:false is set.
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

    # Get a question value by question ID.
    # Input is normalized to lowercase for public API convenience.
    #
    # @param question_id [Symbol, String] the question identifier (any casing)
    # @return [Object, nil] the stored value or nil
    # @raise [UnknownFieldError] if question doesn't exist in questionnaire
    def [](question_id)
      question = lookup_question(question_id)
      @data[question.xbrl_id]
    end

    # Set a question value by question ID.
    # Input is normalized to lowercase for public API convenience.
    # Value is automatically type-cast and stored with original XBRL ID.
    #
    # @param question_id [Symbol, String] the question identifier (any casing)
    # @param value [Object] the value to set (will be type-cast)
    # @raise [UnknownFieldError] if question doesn't exist in questionnaire
    def []=(question_id, value)
      question = lookup_question(question_id)
      @data[question.xbrl_id] = question.cast(value)
    end

    # Get a frozen copy of the data hash (for inspection/serialization).
    # Returns a defensive copy to prevent external mutation.
    # Keys are original XBRL IDs.
    #
    # @return [Hash{Symbol => Object}] frozen question values keyed by XBRL ID
    def data
      @data.dup.freeze
    end

    # Check if all required visible questions are filled.
    #
    # @return [Boolean] true if submission is complete
    def complete?
      unanswered_questions.empty?
    end

    # Get list of visible questions that are not answered.
    # Respects gate visibility - hidden questions are not considered unanswered.
    #
    # @return [Array<Question>] unanswered questions
    def unanswered_questions
      visible_questions.select { |question| question_unanswered?(question) }
    end

    # Calculate completion percentage based on visible questions.
    #
    # @return [Float] percentage from 0.0 to 100.0
    def completion_percentage
      visible = visible_questions
      return 100.0 if visible.empty?

      filled = visible.count { |question| !question_unanswered?(question) }
      (filled.to_f / visible.size * 100).round(1)
    end

    # Check if a question is visible given current gate values.
    # Use this to determine which questions to show in a UI.
    #
    # @param question_id [Symbol, String] the question identifier (any casing)
    # @return [Boolean] true if question should be visible
    # @raise [UnknownFieldError] if question doesn't exist in questionnaire
    def question_visible?(question_id)
      question = lookup_question(question_id)
      question.visible?(@data)
    end

    private

    # Lookup question by any casing, normalize via public API.
    # @param question_id [Symbol, String] the question identifier
    # @return [Question] the question if found
    # @raise [UnknownFieldError] if question doesn't exist
    def lookup_question(question_id)
      normalized_id = question_id.to_s.downcase.to_sym
      question = questionnaire.question(normalized_id)
      raise UnknownFieldError, question_id unless question

      question
    end

    # Get all visible questions (gate dependencies satisfied).
    # Uses internal @data hash which has XBRL ID keys matching depends_on.
    def visible_questions
      questionnaire.questions.select { |question| question.visible?(@data) }
    end

    # Check if a question is unanswered (nil or not set).
    # Uses xbrl_id for internal lookup since @data uses XBRL IDs.
    def question_unanswered?(question)
      !@data.key?(question.xbrl_id) || @data[question.xbrl_id].nil?
    end
  end
end
