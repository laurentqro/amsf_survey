# frozen_string_literal: true

module AmsfSurvey
  # Base error class for all AmsfSurvey errors
  class Error < StandardError; end

  # Base class for taxonomy loading errors
  class TaxonomyLoadError < Error; end

  # Raised when a required taxonomy file is not found
  class MissingTaxonomyFileError < TaxonomyLoadError
    attr_reader :file_path

    def initialize(file_path)
      @file_path = file_path
      super("Taxonomy file not found: #{file_path}")
    end
  end

  # Raised when a taxonomy file cannot be parsed
  class MalformedTaxonomyError < TaxonomyLoadError
    attr_reader :file_path, :parse_error

    def initialize(file_path, parse_error = nil)
      @file_path = file_path
      @parse_error = parse_error
      message = "Malformed taxonomy file: #{file_path}"
      message += " (#{parse_error})" if parse_error
      super(message)
    end
  end

  # Raised when semantic_mappings.yml is missing
  class MissingSemanticMappingError < TaxonomyLoadError
    attr_reader :taxonomy_path

    def initialize(taxonomy_path)
      @taxonomy_path = taxonomy_path
      super("Semantic mappings file not found in: #{taxonomy_path}")
    end
  end
end
