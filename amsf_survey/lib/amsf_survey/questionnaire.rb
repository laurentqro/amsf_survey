# frozen_string_literal: true

module AmsfSurvey
  # Container for an industry/year survey structure.
  # Immutable value object built by the taxonomy loader.
  class Questionnaire
    attr_reader :industry, :year, :sections, :taxonomy_namespace

    def initialize(industry:, year:, sections:, taxonomy_namespace: nil)
      @industry = industry
      @year = year
      @sections = sections
      @taxonomy_namespace = taxonomy_namespace
      @field_index = build_field_index
    end

    # Returns all fields across all sections in order
    # Extracts the Field from each Question in the hierarchy
    def fields
      sections.flat_map(&:questions).map(&:field)
    end

    # Lookup field by lowercase ID
    # Input is normalized to lowercase for consistent lookup
    def field(id)
      @field_index[id.to_s.downcase.to_sym]
    end

    # Total number of fields
    def field_count
      fields.length
    end

    # Number of sections
    def section_count
      sections.length
    end

    # Fields where gate is true
    def gate_fields
      fields.select(&:gate?)
    end

    private

    def build_field_index
      fields.each_with_object({}) do |field, index|
        index[field.id] = field
      end
    end
  end
end
