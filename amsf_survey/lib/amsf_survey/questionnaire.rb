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
    def fields
      sections.flat_map(&:fields)
    end

    # Lookup field by semantic name or XBRL code
    def field(id)
      @field_index[id.to_sym]
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

    # Fields with source_type :computed
    def computed_fields
      fields.select(&:computed?)
    end

    # Fields with source_type :prefillable
    def prefillable_fields
      fields.select(&:prefillable?)
    end

    # Fields with source_type :entry_only
    def entry_only_fields
      fields.select(&:entry_only?)
    end

    private

    def build_field_index
      index = {}
      fields.each do |field|
        index[field.id] = field
        index[field.name] = field if field.name != field.id
      end
      index
    end
  end
end
