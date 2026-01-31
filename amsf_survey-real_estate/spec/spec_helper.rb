# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../../amsf_survey/lib", __dir__)
require "amsf_survey/real_estate"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  config.order = :random
  Kernel.srand config.seed

  # Skip arelle tests unless ARELLE env var is set
  config.filter_run_excluding arelle: true unless ENV["ARELLE"]
end
