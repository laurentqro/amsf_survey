# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "amsf_survey-real_estate"
  spec.version = "0.1.0"
  spec.authors = ["AMSF Survey Team"]
  spec.email = ["amsf-survey@example.com"]

  spec.summary = "Real estate industry plugin for AMSF Survey"
  spec.description = "Provides real estate AML/CFT taxonomy for Monaco AMSF regulatory surveys"
  spec.homepage = "https://github.com/example/amsf_survey"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "taxonomies/**/*", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "amsf_survey", "~> 0.1"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
