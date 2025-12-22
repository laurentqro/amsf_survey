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
  # Load I18n translations for validation messages
  LOCALE_PATH = File.expand_path("amsf_survey/locales/*.yml", __dir__)
  I18n.load_path += Dir[LOCALE_PATH]
  I18n.default_locale = :fr # Monaco regulatory context - French is primary
end
