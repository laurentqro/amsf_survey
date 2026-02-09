# frozen_string_literal: true

module AmsfSurvey
  # Shared locale resolution for model classes that store translatable text.
  # Provides normalize_locale_hash and resolve_locale for consistent behavior.
  module LocaleSupport
    private

    # Normalizes a value into a locale hash.
    # - Hash with symbol keys → used as-is
    # - Hash with string keys → symbolized
    # - String → stored under :fr (backward compatibility)
    # - nil → empty hash
    def normalize_locale_hash(value)
      case value
      when Hash
        value.transform_keys(&:to_sym)
      when String
        { fr: value }
      else
        {}
      end
    end

    # Resolves a locale from a hash with fallback chain:
    # requested locale → :fr → first available value → nil
    def resolve_locale(hash, locale)
      return nil if hash.empty?

      locale_sym = locale&.to_sym
      hash[locale_sym] || hash[:fr] || hash.values.first
    end
  end
end
