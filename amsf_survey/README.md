# AmsfSurvey

Ruby gem for Monaco AMSF (Autorité Monégasque de Supervision Financière) AML/CFT regulatory survey submissions.

## Installation

Add to your Gemfile:

```ruby
gem 'amsf_survey'
```

Then run:

```bash
bundle install
```

## Usage

```ruby
require 'amsf_survey'

# Check registered industries (empty without plugins)
AmsfSurvey.registered_industries
# => []

# Check if an industry is registered
AmsfSurvey.registered?(:real_estate)
# => false
```

## Industry Plugins

Install industry-specific plugins to enable survey functionality:

```ruby
gem 'amsf_survey-real_estate'
```

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT License
