# AmsfSurvey

Ruby gem for Monaco AMSF (Autorité Monégasque de Supervision Financière) AML/CFT regulatory survey submissions. Generates XBRL instance documents for the Strix portal.

## Overview

Real estate professionals in Monaco must submit annual AML/CFT surveys to AMSF via the Strix portal. This gem:

1. **Parses XBRL taxonomy files** - Understands the 323-field questionnaire structure
2. **Provides direct XBRL ID access** - Use field IDs like `:aactive`, `:a1101` directly
3. **Tracks submission completeness** - Checks which required fields are missing
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
│  • Generator (XBRL output)  │    - *_pre.xml (presentation)     │
│  • Registry                 │    - *.xule (validation rules)    │
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

# Create submission using XBRL field IDs (lowercase)
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "MY_AGENCY_001",
  period: Date.new(2025, 12, 31)
)

# Set values using lowercase field IDs
submission[:aactive] = "Oui"           # Gate: Did you act as professional agent?
submission[:a1101] = 42                # Total unique clients
submission[:a1102] = 10                # National individuals
submission[:a1103] = 20                # Foreign residents
submission[:a1104] = 12                # Non-residents

# Track completion
puts "Complete: #{submission.complete?}"
puts "Missing: #{submission.missing_fields}"

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
q.field(:aactive)   # => Field object (lookup by lowercase ID)
q.field(:a1101)     # => Field object (any casing works, normalized to lowercase)
```

### Field

Fields use a dual-ID system:
- `id` - Lowercase symbol for API access (`:aactive`, `:a1101`)
- `xbrl_id` - Original casing for XBRL generation (`:aACTIVE`, `:a1101`)

```ruby
field = q.field(:aactive)

field.id          # => :aactive (lowercase for API)
field.xbrl_id     # => :aACTIVE (original casing for XBRL)
field.type        # => :integer, :boolean, :monetary, :string, :enum
field.label       # => French question text
field.gate?       # => true if this controls visibility of other fields
field.visible?(data)  # => checks gate dependencies
```

### Submission

```ruby
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "MONACO_RE_001",
  period: Date.new(2025, 12, 31)
)

# Set values using any casing (normalized at public API boundary)
submission[:aactive] = "Oui"
submission[:a1101] = 150

submission.complete?              # => false (not all fields filled)
submission.completion_percentage  # => 0.6%
submission.missing_fields         # => [:a1102, :a1103, ...] (lowercase IDs)
submission[:a1101]                # => 150

# Internal data uses original XBRL IDs
submission.data                   # => { aACTIVE: "Oui", a1101: 150 }
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
# Check if a field is a gate question
field = q.field(:aactive)  # "Did you act as a professional agent?"
field.gate?  # => true

# Visibility is handled automatically by Submission
submission[:aactive] = "Non"
submission.missing_fields  # Only includes fields visible given current gate values
```

The submission respects gate visibility - hidden fields are not counted as missing.

## Field ID Access

The gem uses XBRL element IDs directly. There's no separate semantic mapping layer.

| XBRL ID | Lowercase API ID | Description |
|---------|------------------|-------------|
| `aACTIVE` | `:aactive` | Did you act as a professional agent? |
| `a1101` | `:a1101` | Total unique clients during reporting period |
| `a11301` | `:a11301` | Do you have PEP clients? |
| `a13501B` | `:a13501b` | Do you have VASP clients? |

Field lookup normalizes any casing to lowercase internally.

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
| `Loader` | All files | Orchestrates into `Questionnaire` |

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
│       └── strix_*.xule
└── amsf_survey-yachting.gemspec
```

## Development

```bash
bundle install
bundle exec rspec
```

Test coverage: 99.47% line coverage, 310 tests.

## License

MIT License
