# frozen_string_literal: true

module AmsfSurvey
  # Represents a single survey question with all metadata.
  # Immutable value object built by the taxonomy loader.
  class Field
    include LocaleSupport

    attr_reader :xbrl_id, :type, :xbrl_type,
                :valid_values,
                :depends_on, :gate, :min, :max,
                :dimensional, :enum_needs_encoding

    def initialize(
      id:,
      type:,
      xbrl_type:,
      label:,
      gate:,
      verbose_label: nil,
      valid_values: nil,
      depends_on: {},
      min: nil,
      max: nil,
      dimensional: false,
      enum_needs_encoding: false
    )
      @xbrl_id = id
      @id = id.to_s.downcase.to_sym
      @type = type
      @xbrl_type = xbrl_type
      @labels = normalize_locale_hash(label)
      @verbose_labels = normalize_locale_hash(verbose_label)
      @gate = gate
      @valid_values = valid_values
      @depends_on = depends_on || {}
      @min = min
      @max = max
      @dimensional = dimensional
      @enum_needs_encoding = enum_needs_encoding
    end

    # Returns lowercase ID for API usage (e.g., :aactive, :a1101)
    def id
      @id
    end

    # Returns label for the given locale, with fallback chain:
    # requested locale → :fr → first available value
    def label(locale = AmsfSurvey.locale)
      resolve_locale(@labels, locale)
    end

    # Returns verbose label for the given locale, with fallback chain
    def verbose_label(locale = AmsfSurvey.locale)
      resolve_locale(@verbose_labels, locale)
    end

    # Check if this field has range constraints.
    def has_range?
      !@min.nil? || !@max.nil?
    end

    # Type predicates
    def boolean? = type == :boolean
    def integer? = type == :integer
    def decimal? = type == :decimal
    def string? = type == :string
    def monetary? = type == :monetary
    def enum? = type == :enum
    def percentage? = type == :percentage
    def date? = type == :date

    # Dimensional predicate
    def dimensional? = dimensional

    # Gate predicates
    def gate? = gate

    # Cast a value to the appropriate type for this field.
    def cast(value)
      TypeCaster.cast(value, type)
    end

    # Resolves a short code (e.g. ISO alpha-2 "FR") to the matching XBRL
    # enum label from valid_values (e.g. "France (FR, FRA, 250)").
    # Returns nil when no match is found or valid_values is nil.
    def resolve_code(code)
      return nil if code.nil? || valid_values.nil?

      normalized = code.to_s.strip.upcase
      return nil if normalized.empty?

      @code_lookup ||= build_code_lookup
      @code_lookup[normalized]
    end

    # Evaluates gate dependencies against internal submission data.
    # Used by Submission#visible_fields - not part of public API.
    #
    # IMPORTANT: Data hash MUST use Symbol keys (original XBRL IDs) to match
    # depends_on. String keys will cause silent lookup failures.
    def visible?(data)
      return true if depends_on.empty?

      depends_on.all? do |gate_id, required_value|
        data.key?(gate_id) && data[gate_id] == required_value
      end
    end

    private :visible?

    private

    # Builds a hash mapping alpha-2 codes to their full XBRL labels.
    # Entries without parenthesized codes (e.g. "Kosovo") are skipped.
    def build_code_lookup
      return {} if valid_values.nil?

      valid_values.each_with_object({}) do |label, lookup|
        next unless label =~ /\(([A-Z]{2}),\s/

        lookup[Regexp.last_match(1)] = label
      end
    end
  end
end
