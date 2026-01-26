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

  # Raised when attempting to access or set a field that doesn't exist in the questionnaire
  class UnknownFieldError < Error
    attr_reader :field_id

    def initialize(field_id)
      @field_id = field_id
      super("Unknown field: #{field_id}")
    end
  end

  # Raised when XBRL generation fails due to invalid submission data
  class GeneratorError < Error; end

  # Raised when questionnaire_structure.yml is not found
  class MissingStructureFileError < TaxonomyLoadError
    attr_reader :file_path

    def initialize(file_path)
      @file_path = file_path
      super("Structure file not found: #{file_path}")
    end
  end

  # Raised when a field appears multiple times in questionnaire_structure.yml
  class DuplicateFieldError < TaxonomyLoadError
    attr_reader :field_id, :location

    def initialize(field_id, location)
      @field_id = field_id
      @location = location
      super("Duplicate field '#{field_id}' in #{location}")
    end
  end
end
