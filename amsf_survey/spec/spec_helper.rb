# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
  # Line coverage must be 100%, branch coverage set lower due to safe navigation operators
  # which are defensive coding patterns that don't all need explicit testing
  minimum_coverage line: 100, branch: 60
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "amsf_survey"

RSpec.configure do |config|
  # Use English locale for test assertions (messages are predictable)
  config.before(:suite) do
    I18n.locale = :en
  end

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
end
