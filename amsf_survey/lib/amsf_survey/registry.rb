# frozen_string_literal: true

module AmsfSurvey
  class Error < StandardError; end
  class TaxonomyPathError < Error; end
  class DuplicateIndustryError < Error; end

  class << self
    # Returns list of registered industry symbols
    # @return [Array<Symbol>] registered industry identifiers
    def registered_industries
      registry.keys
    end

    # Check if an industry is registered
    # @param industry [Symbol] the industry identifier
    # @return [Boolean] true if registered
    def registered?(industry)
      registry.key?(industry)
    end

    # Get supported years for an industry
    # @param industry [Symbol] the industry identifier
    # @return [Array<Integer>] available years, empty if not registered
    def supported_years(industry)
      return [] unless registered?(industry)

      taxonomy_path = registry[industry][:taxonomy_path]
      detect_years(taxonomy_path)
    end

    # Load questionnaire for an industry and year
    # Results are cached for performance
    # @param industry [Symbol] the industry identifier
    # @param year [Integer] the taxonomy year
    # @return [Questionnaire] loaded questionnaire
    # @raise [TaxonomyLoadError] if industry not registered or year not supported
    def questionnaire(industry:, year:)
      validate_industry!(industry)
      validate_year!(industry, year)

      cache_key = [industry, year]
      questionnaire_cache[cache_key] ||= load_questionnaire(industry, year)
    end

    # Create a new submission for an industry and year
    # @param industry [Symbol] the industry identifier
    # @param year [Integer] the taxonomy year
    # @param entity_id [String] unique identifier for the reporting entity
    # @param period [Date] reporting period end date
    # @return [Submission] new submission object
    # @raise [TaxonomyLoadError] if industry not registered or year not supported
    def build_submission(industry:, year:, entity_id:, period:)
      # Validate upfront to fail fast
      validate_industry!(industry)
      validate_year!(industry, year)

      Submission.new(
        industry: industry,
        year: year,
        entity_id: entity_id,
        period: period
      )
    end

    # Generate XBRL instance XML from a submission
    # @param submission [Submission] the source submission
    # @param options [Hash] generation options
    # @option options [Boolean] :pretty (false) output indented XML
    # @option options [Boolean] :include_empty (true) include empty facts for nil values
    # @return [String] XBRL instance XML
    def to_xbrl(submission, **options)
      Generator.new(submission, options).generate
    end

    # Get schema_url for an industry and year (for sync scripts)
    # @param industry [Symbol] the industry identifier
    # @param year [Integer] the taxonomy year
    # @return [String, nil] the schema URL or nil if not available
    def schema_url_for(industry:, year:)
      return nil unless registered?(industry)
      return nil unless supported_years(industry).include?(year)

      questionnaire(industry: industry, year: year).schema_url
    end

    # Reset registry state (for testing only)
    # @api private
    def reset_registry! # :nodoc:
      @registry = {}
      @questionnaire_cache = {}
      @locale = nil
    end

    # Register an industry plugin
    # @param industry [Symbol] unique industry identifier
    # @param taxonomy_path [String] path to taxonomy directory
    # @raise [TaxonomyPathError] if path does not exist
    # @raise [DuplicateIndustryError] if industry already registered
    def register_plugin(industry:, taxonomy_path:)
      validate_taxonomy_path!(taxonomy_path)
      validate_unique_industry!(industry)

      registry[industry] = { taxonomy_path: taxonomy_path }
    end

    private

    def registry
      @registry ||= {}
    end

    def validate_taxonomy_path!(path)
      return if File.directory?(path)

      raise TaxonomyPathError, "Taxonomy path does not exist: #{path}"
    end

    def validate_unique_industry!(industry)
      return unless registered?(industry)

      raise DuplicateIndustryError, "Industry already registered: #{industry}"
    end

    def detect_years(taxonomy_path)
      Dir.children(taxonomy_path)
         .select { |entry| entry.match?(/^(19|20)\d{2}$/) }
         .select { |entry| File.directory?(File.join(taxonomy_path, entry)) }
         .map(&:to_i)
         .sort
    end

    def questionnaire_cache
      @questionnaire_cache ||= {}
    end

    def validate_industry!(industry)
      return if registered?(industry)

      available = registered_industries
      message = if available.empty?
                  "Industry not registered: #{industry}. No industries registered yet."
                else
                  "Industry not registered: #{industry}. Available: #{available.join(', ')}"
                end
      raise TaxonomyLoadError, message
    end

    def validate_year!(industry, year)
      unless year.is_a?(Integer) && year.positive?
        raise TaxonomyLoadError, "Invalid year: #{year}. Must be a positive integer."
      end

      return if supported_years(industry).include?(year)

      available = supported_years(industry)
      message = if available.empty?
                  "Year not supported for #{industry}: #{year}. No years available."
                else
                  "Year not supported for #{industry}: #{year}. Available: #{available.join(', ')}"
                end
      raise TaxonomyLoadError, message
    end

    def load_questionnaire(industry, year)
      taxonomy_path = File.join(registry[industry][:taxonomy_path], year.to_s)
      Taxonomy::Loader.new(taxonomy_path).load(industry, year)
    end
  end
end
