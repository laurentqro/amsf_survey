# frozen_string_literal: true

require_relative "amsf_survey/version"
require_relative "amsf_survey/errors"
require_relative "amsf_survey/type_caster"
require_relative "amsf_survey/field"
require_relative "amsf_survey/question"
require_relative "amsf_survey/subsection"
require_relative "amsf_survey/section"
require_relative "amsf_survey/questionnaire"
require_relative "amsf_survey/submission"
require_relative "amsf_survey/generator"
require_relative "amsf_survey/taxonomy/schema_parser"
require_relative "amsf_survey/taxonomy/label_parser"
require_relative "amsf_survey/taxonomy/xule_parser"
require_relative "amsf_survey/taxonomy/structure_parser"
require_relative "amsf_survey/taxonomy/loader"
require_relative "amsf_survey/registry"

module AmsfSurvey
  # Core gem for AMSF regulatory survey submissions.
  # Validation is delegated to Arelle (external XBRL validator).
  # The gem provides completeness tracking via submission.complete? and submission.unanswered_questions.
end
