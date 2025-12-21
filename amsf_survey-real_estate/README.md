# AmsfSurvey::RealEstate

Real estate industry plugin for the AMSF Survey gem. Provides Monaco AMSF AML/CFT taxonomy for real estate professionals.

## Installation

Add both gems to your Gemfile:

```ruby
gem 'amsf_survey'
gem 'amsf_survey-real_estate'
```

Then run:

```bash
bundle install
```

## Usage

```ruby
require 'amsf_survey'
require 'amsf_survey/real_estate'

# Plugin auto-registers on require
AmsfSurvey.registered_industries
# => [:real_estate]

AmsfSurvey.registered?(:real_estate)
# => true

AmsfSurvey.supported_years(:real_estate)
# => [2025]
```

## Taxonomy Files

This plugin includes the official Strix taxonomy files for real estate AML/CFT surveys:

- `strix_Real_Estate_AML_CFT_survey_2025.xsd` - Schema definition
- `strix_Real_Estate_AML_CFT_survey_2025_lab.xml` - Labels (French)
- `strix_Real_Estate_AML_CFT_survey_2025_def.xml` - Definition linkbase
- `strix_Real_Estate_AML_CFT_survey_2025_pre.xml` - Presentation linkbase
- `strix_Real_Estate_AML_CFT_survey_2025_cal.xml` - Calculation linkbase
- `strix_Real_Estate_AML_CFT_survey_2025.xule` - Validation rules

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT License
