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

    # Reset registry state (for testing only)
    # @api private
    def reset_registry! # :nodoc:
      @registry = {}
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
  end
end
