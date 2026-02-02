# frozen_string_literal: true

require_relative "lib/amsf_survey/version"

Gem::Specification.new do |spec|
  spec.name = "amsf_survey"
  spec.version = AmsfSurvey::VERSION
  spec.authors = ["AMSF Survey Team"]
  spec.email = ["amsf-survey@lqro.slmail.me"]

  spec.summary = "Ruby gem for Monaco AMSF AML/CFT regulatory survey submissions"
  spec.description = "Industry-agnostic core gem for AMSF survey questionnaires, validation, and XBRL generation"
  spec.homepage = "https://github.com/example/amsf_survey"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", "~> 1.15"
  spec.add_dependency "bigdecimal" # Required for Ruby 3.4+

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
