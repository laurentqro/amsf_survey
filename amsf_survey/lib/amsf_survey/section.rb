# frozen_string_literal: true

module AmsfSurvey
  # Represents a logical grouping of fields from a presentation link.
  # Immutable value object built by the taxonomy loader.
  class Section
    attr_reader :id, :name, :order, :fields

    def initialize(id:, name:, order:, fields:)
      @id = id
      @name = name
      @order = order
      @fields = fields
    end

    # Returns the number of fields in this section
    def field_count
      fields.length
    end

    # Returns true if section has no fields
    def empty?
      fields.empty?
    end

    # Returns true if any field in the section is visible given the data
    def visible?(data)
      return false if empty?

      fields.any? { |field| field.visible?(data) }
    end
  end
end
