# frozen_string_literal: true

require "i18n"

require_relative "amsf_survey/version"
require_relative "amsf_survey/errors"
require_relative "amsf_survey/type_caster"
require_relative "amsf_survey/field"
require_relative "amsf_survey/section"
require_relative "amsf_survey/questionnaire"
require_relative "amsf_survey/submission"
require_relative "amsf_survey/validation_error"
require_relative "amsf_survey/validation_result"
require_relative "amsf_survey/validator"
require_relative "amsf_survey/taxonomy/schema_parser"
require_relative "amsf_survey/taxonomy/label_parser"
require_relative "amsf_survey/taxonomy/presentation_parser"
require_relative "amsf_survey/taxonomy/xule_parser"
require_relative "amsf_survey/taxonomy/loader"
require_relative "amsf_survey/registry"

module AmsfSurvey
  # Default locale for validation messages (Monaco regulatory context)
  # Host applications can override via the locale: parameter on validate()
  DEFAULT_LOCALE = :fr

  # Load I18n translations for validation messages (additive, safe for gems)
  LOCALE_PATH = File.expand_path("amsf_survey/locales/*.yml", __dir__)
  I18n.load_path += Dir[LOCALE_PATH]

  # Note: We intentionally do NOT mutate I18n.default_locale, available_locales,
  # or fallbacks here. Host applications control those settings.
  # Use AmsfSurvey::Validator.validate(submission, locale: :fr) to specify locale.
end
