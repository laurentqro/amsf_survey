# frozen_string_literal: true

require "amsf_survey"
require_relative "real_estate/version"

module AmsfSurvey
  module RealEstate
    TAXONOMY_PATH = File.expand_path("../../taxonomies", __dir__)
  end
end

# Auto-register on require
AmsfSurvey.register_plugin(
  industry: :real_estate,
  taxonomy_path: AmsfSurvey::RealEstate::TAXONOMY_PATH
)
