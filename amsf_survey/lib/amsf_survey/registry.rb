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

    # Reset registry state (for testing only)
    # @api private
    def reset_registry! # :nodoc:
      @registry = {}
      @questionnaire_cache = {}
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

      raise TaxonomyLoadError, "Industry not registered: #{industry}"
    end

    def validate_year!(industry, year)
      unless year.is_a?(Integer) && year.positive?
        raise TaxonomyLoadError, "Invalid year: #{year}. Must be a positive integer."
      end

      return if supported_years(industry).include?(year)

      raise TaxonomyLoadError, "Year not supported for #{industry}: #{year}"
    end

    def load_questionnaire(industry, year)
      taxonomy_path = File.join(registry[industry][:taxonomy_path], year.to_s)
      Taxonomy::Loader.new(taxonomy_path).load(industry, year)
    end
  end
end
