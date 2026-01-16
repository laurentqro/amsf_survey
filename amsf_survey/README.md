# AmsfSurvey

Ruby gem for Monaco AMSF (Autorité Monégasque de Supervision Financière) AML/CFT regulatory survey submissions. Generates and validates XBRL instance documents for the Strix portal.

## Overview

Real estate professionals in Monaco must submit annual AML/CFT surveys to AMSF via the Strix portal. This gem:

1. **Parses XBRL taxonomy files** - Understands the 323-field questionnaire structure
2. **Provides a semantic Ruby API** - No XBRL knowledge needed for consumers
3. **Validates submissions** - Checks required fields, ranges, conditional logic
4. **Generates XBRL XML** - Output format the Strix portal accepts

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MONOREPO                                  │
├─────────────────────────────┬───────────────────────────────────┤
│      amsf_survey/           │    amsf_survey-real_estate/       │
│      (Core Gem)             │    (Industry Plugin)              │
│                             │                                   │
│  • Questionnaire            │  • taxonomies/2025/               │
│  • Section, Field           │    - *.xsd (schema)               │
│  • Submission               │    - *_lab.xml (French labels)    │
│  • Validator                │    - *_pre.xml (presentation)     │
│  • Generator (XBRL output)  │    - *.xule (validation rules)    │
│  • Registry                 │    - semantic_mappings.yml        │
│  • Taxonomy Parsers         │                                   │
└─────────────────────────────┴───────────────────────────────────┘
```

The core gem knows nothing about real estate. Industry plugins provide taxonomy files and register themselves on require.

## Installation

Add to your Gemfile:

```ruby
gem 'amsf_survey'
gem 'amsf_survey-real_estate'  # Industry plugin
```

Then run:

```bash
bundle install
```

## Quick Start

```ruby
require 'amsf_survey/real_estate'  # Auto-registers the plugin

# Load questionnaire
q = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

# Build submission with semantic field names
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "MY_AGENCY_001",
  period: Date.new(2025, 12, 31),
  data: {
    has_activity: true,
    has_activity_purchase_sale: true,
    total_clients: 42,
    clients_nationals: 10,
    clients_foreign_residents: 20,
    clients_non_residents: 12
  }
)

# Validate
result = AmsfSurvey.validate(submission)
puts result.valid? ? "Ready to submit!" : result.errors

# Generate XBRL for Strix portal
xml = AmsfSurvey.to_xbrl(submission, pretty: true)
File.write("submission_2025.xml", xml)
```

## Core API

### Registry

```ruby
# Check registered industries
AmsfSurvey.registered_industries
# => [:real_estate]

# Check if an industry is registered
AmsfSurvey.registered?(:real_estate)
# => true

# Get supported years
AmsfSurvey.supported_years(:real_estate)
# => [2025]
```

### Questionnaire

```ruby
q = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

q.fields.count      # => 323
q.sections          # => [Section, Section, ...]
q.field(:has_pep_clients)  # => Field object (by semantic name)
q.field(:a11301)    # => Field object (by XBRL code)
```

### Field

```ruby
field = q.field(:total_clients)

field.id          # => :total_clients (semantic) or :a1101 (XBRL code)
field.type        # => :integer, :boolean, :monetary, :string, :enum
field.label       # => French question text
field.required?   # => true/false
field.gate?       # => true if this controls visibility of other fields
field.visible?(data)  # => checks gate dependencies
```

### Submission

```ruby
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "MONACO_RE_001",
  period: Date.new(2025, 12, 31),
  data: { has_activity: true, total_clients: 150 }
)

submission.complete?              # => false (not all fields filled)
submission.completion_percentage  # => 0.6%
submission.missing_fields         # => [:clients_nationals, ...]
submission[:total_clients]        # => 150
```

### Validator

```ruby
result = AmsfSurvey.validate(submission)

result.valid?     # => true/false
result.complete?  # => true/false (all required fields present)
result.errors     # => [{field: :total_clients, rule: :presence, message: "..."}]
result.warnings   # => []

# With locale (default is :fr for Monaco regulatory context)
result = AmsfSurvey.validate(submission, locale: :en)
```

### Generator

```ruby
# Generate XBRL instance document
xml = AmsfSurvey.to_xbrl(submission)

# With options
xml = AmsfSurvey.to_xbrl(submission, pretty: true)           # Indented output
xml = AmsfSurvey.to_xbrl(submission, include_empty: false)   # Omit nil fields
```

## Gate Questions (Conditional Logic)

Some fields only appear based on answers to "gate" questions:

```ruby
# If has_activity = false, most fields become hidden/optional
field = q.field(:has_activity)  # "Did you act as a professional agent?"
field.gate?  # => true

# Dependent fields check visibility
client_field = q.field(:total_clients)
client_field.visible?({ has_activity: false })  # => false (hidden)
client_field.visible?({ has_activity: true })   # => true (visible)
```

The validator respects gate visibility - hidden fields are not required.

## Semantic Mappings

The gem maps cryptic XBRL codes to readable Ruby field names:

| XBRL Code | Semantic Name | Description |
|-----------|---------------|-------------|
| `aACTIVE` | `has_activity` | Did you act as a professional agent? |
| `a1101` | `total_clients` | Total unique clients during reporting period |
| `a11301` | `has_pep_clients` | Do you have PEP clients? |
| `a13501B` | `has_vasp_clients` | Do you have VASP clients? |

Mappings are defined in `semantic_mappings.yml` within each industry plugin.

## Field Types

| Type | Ruby Type | Example |
|------|-----------|---------|
| `:boolean` | `String` | `"Oui"` / `"Non"` |
| `:integer` | `Integer` | `42` |
| `:monetary` | `BigDecimal` | `BigDecimal("1234.56")` |
| `:string` | `String` | `"Free text"` |
| `:enum` | `String` | `"Option A"` |

## Taxonomy Parsers

The gem parses official AMSF XBRL taxonomy files:

| Parser | File | What It Extracts |
|--------|------|------------------|
| `SchemaParser` | `.xsd` | Field IDs, types, valid enum values |
| `LabelParser` | `_lab.xml` | French question text |
| `PresentationParser` | `_pre.xml` | Section structure, field ordering |
| `XuleParser` | `.xule` | Gate question dependencies |
| `Loader` | All + `semantic_mappings.yml` | Orchestrates into `Questionnaire` |

## Creating Industry Plugins

Plugins are minimal - just taxonomy files and registration:

```ruby
# lib/amsf_survey/yachting.rb
require "amsf_survey"

AmsfSurvey.register_plugin(
  industry: :yachting,
  taxonomy_path: File.expand_path("../../taxonomies", __dir__)
)
```

Directory structure:

```
amsf_survey-yachting/
├── lib/
│   └── amsf_survey/
│       └── yachting.rb
├── taxonomies/
│   └── 2025/
│       ├── strix_*.xsd
│       ├── strix_*_lab.xml
│       ├── strix_*_pre.xml
│       ├── strix_*.xule
│       └── semantic_mappings.yml
└── amsf_survey-yachting.gemspec
```

## Development

```bash
bundle install
bundle exec rspec
```

Test coverage: 99.47% line coverage, 374 tests.

## License

MIT License
