# frozen_string_literal: true

require_relative "amsf_survey/version"
require_relative "amsf_survey/errors"
require_relative "amsf_survey/field"
require_relative "amsf_survey/section"
require_relative "amsf_survey/questionnaire"
require_relative "amsf_survey/taxonomy/schema_parser"
require_relative "amsf_survey/taxonomy/label_parser"
require_relative "amsf_survey/taxonomy/presentation_parser"
require_relative "amsf_survey/taxonomy/xule_parser"
require_relative "amsf_survey/taxonomy/loader"
require_relative "amsf_survey/registry"

module AmsfSurvey
  # Core gem initialization - registry is empty until plugins register
end
