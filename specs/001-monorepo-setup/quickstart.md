# Quickstart: AMSF Survey Gem

## Installation

Add the core gem and desired industry plugin to your Gemfile:

```ruby
gem 'amsf_survey'
gem 'amsf_survey-real_estate'
```

Run bundler:

```bash
bundle install
```

## Basic Usage

```ruby
require 'amsf_survey'
require 'amsf_survey/real_estate'

# Check registered industries
AmsfSurvey.registered_industries
# => [:real_estate]

# Verify a specific industry is available
AmsfSurvey.registered?(:real_estate)
# => true

AmsfSurvey.registered?(:yachting)
# => false

# Get supported years for an industry
AmsfSurvey.supported_years(:real_estate)
# => [2025]
```

## Development Setup

### Core Gem

```bash
cd amsf_survey
bundle install
bundle exec rspec
```

### Plugin Gem

```bash
cd amsf_survey-real_estate
bundle install
bundle exec rspec
```

### Building Gems

```bash
# Build core gem
cd amsf_survey
gem build amsf_survey.gemspec

# Build plugin gem
cd amsf_survey-real_estate
gem build amsf_survey-real_estate.gemspec
```

## Verification Checklist

After setup, verify:

1. `gem build amsf_survey.gemspec` produces a valid `.gem` file
2. `gem build amsf_survey-real_estate.gemspec` produces a valid `.gem` file
3. `require 'amsf_survey'` loads without errors
4. `require 'amsf_survey/real_estate'` registers the plugin
5. `bundle exec rspec` passes in both gem directories
6. Coverage reports show 100% coverage
