# AmsfSurvey

Ruby gem for Monaco AMSF (Autorité Monégasque de Supervision Financière) AML/CFT regulatory survey submissions. Generates XBRL instance documents for the Strix portal.

## Overview

Real estate professionals in Monaco must submit annual AML/CFT surveys to AMSF via the Strix portal. This gem:

1. **Parses XBRL taxonomy files** - Understands the 322-question questionnaire structure
2. **Provides direct XBRL ID access** - Use question IDs like `:aactive`, `:a1101` directly
3. **Tracks submission completeness** - Checks which required questions are unanswered
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
│  • Section, Subsection      │    - *.xsd (schema)               │
│  • Question                 │    - *_lab.xml (French labels)    │
│  • Submission               │    - questionnaire_structure.yml  │
│  • Generator (XBRL output)  │    - *.xule (validation rules)    │
│  • Registry                 │                                   │
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
puts "Unanswered: #{submission.unanswered_questions.map(&:id)}"

# Generate XBRL for Strix portal
xml = AmsfSurvey.to_xbrl(submission, pretty: true)
File.write("submission_2025.xml", xml)
```

## Object Hierarchy

The questionnaire follows a hierarchical structure that mirrors the official PDF:

```
Questionnaire
├── industry            # :real_estate
├── year                # 2025
├── taxonomy_namespace  # "https://amlcft.amsf.mc/..."
│
└── parts[]             # Part objects (NEW)
    ├── name            # "Inherent Risk", "Controls", "Signatories"
    │
    └── sections[]
        ├── number      # 1, 2, 3... (explicit from YAML)
        ├── title       # "Customer Risk"
        │
        └── subsections[]
            ├── number      # "1.1", "1.2"... (string, explicit from YAML)
            ├── title       # "Active in Reporting Cycle"
            │
            └── questions[]
                ├── number        # 1, 2, 3... (explicit, resets per Part)
                ├── instructions  # "Activities subject to law..." (from YAML)
                │
                │ # XBRL attributes (from taxonomy files):
                ├── id            # :aactive (lowercase for API)
                ├── xbrl_id       # :aACTIVE (original casing)
                ├── label         # "Avez-vous exercé..." (French text)
                ├── verbose_label # Extended help text
                ├── type          # :boolean, :integer, :monetary, :string, :enum
                ├── valid_values  # ["Oui", "Non"] for boolean/enum
                ├── gate?         # true if controls other questions
                └── depends_on    # { aACTIVE: "Oui" } gate dependencies
```

**Question Numbering:** Question numbers are explicit in the YAML and reset at each Part boundary:
- Inherent Risk: Q1-Q214
- Controls: Q1-Q105
- Signatories: Q1-Q3

### Traversing the Hierarchy

```ruby
q = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

# Iterate all parts (top-level)
q.parts.each do |part|
  puts "#{part.name} (#{part.question_count} questions)"

  part.sections.each do |section|
    puts "  Section #{section.number}: #{section.title}"

    section.subsections.each do |subsection|
      puts "    #{subsection.number}. #{subsection.title}"

      subsection.questions.each do |question|
        puts "      Q#{question.number}: #{question.label}"
        puts "        ID: #{question.id}, Type: #{question.type}"
      end
    end
  end
end

# Direct question lookup (skips hierarchy)
question = q.question(:a1101)
puts question.label  # => French question text

# Access parts directly
inherent_risk = q.parts.find { |p| p.name == "Inherent Risk" }
puts inherent_risk.question_count  # => 214
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

q.parts               # => [Part, Part, Part] (Inherent Risk, Controls, Signatories)
q.part_count          # => 3
q.questions           # => [Question, Question, ...] all questions in order
q.question_count      # => 322
q.sections            # => [Section, Section, ...] (derived from all parts)
q.question(:aactive)  # => Question object (lookup by lowercase ID)
q.question(:a1101)    # => Question object (any casing works, normalized to lowercase)
q.gate_questions      # => Questions that control visibility of others
```

### Part, Section & Subsection

The questionnaire uses a hierarchical structure matching the PDF:

```ruby
# Parts (top-level)
part = q.parts.first
part.name                  # => "Inherent Risk"
part.sections              # => [Section, Section, ...]
part.questions             # => All questions in this part
part.question_count        # => 214

# Sections
section = part.sections.first
section.title              # => "Customer Risk"
section.number             # => 1
section.subsections        # => [Subsection, Subsection, ...]
section.questions          # => All questions across all subsections
section.question_count     # => Total questions in section

# Subsections
subsection = section.subsections.first
subsection.title           # => "Active in Reporting Cycle"
subsection.number          # => "1.1" (string)
subsection.questions       # => [Question, Question, ...]
subsection.question_count  # => 3
```

### Question

Questions are the primary unit of the questionnaire, combining XBRL metadata with PDF-sourced structure:

```ruby
question = q.questions.first
question.number            # => 1 (from PDF)
question.instructions      # => "Activities subject to law..." (from PDF)

# XBRL attributes:
question.id                # => :aactive (lowercase for API)
question.xbrl_id           # => :aACTIVE (original casing for XBRL)
question.label             # => French question text
question.verbose_label     # => Extended help text (if available)
question.type              # => :boolean, :integer, :monetary, :string, :enum
question.valid_values      # => ["Oui", "Non"] for boolean/enum types
question.gate?             # => true if this controls visibility of others
question.depends_on        # => { aACTIVE: "Oui" } gate dependencies
question.visible?(data)    # => checks gate dependencies
```

Questions use a dual-ID system:
- `id` - Lowercase symbol for API access (`:aactive`, `:a1101`)
- `xbrl_id` - Original casing for XBRL generation (`:aACTIVE`, `:a1101`)

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

submission.complete?              # => false (not all questions filled)
submission.completion_percentage  # => 0.6%
submission.unanswered_questions   # => [Question, Question, ...] (visible questions without values)
submission.question_visible?(:a1101) # => true (check if question should be shown in UI)
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

Some questions only appear based on answers to "gate" questions:

```ruby
# Check if a question is a gate
question = q.question(:aactive)  # "Did you act as a professional agent?"
question.gate?  # => true

# Check question visibility for UI rendering
submission[:aactive] = "Non"
submission.question_visible?(:a1101)  # => false (hidden because gate is "Non")

submission[:aactive] = "Oui"
submission.question_visible?(:a1101)  # => true (visible because gate is "Oui")

# Completeness respects gate visibility
submission.unanswered_questions  # Only includes questions visible given current gate values
```

The submission respects gate visibility - hidden questions are not counted as missing.

## Question ID Access

The gem uses XBRL element IDs directly. There's no separate semantic mapping layer.

| XBRL ID | Lowercase API ID | Description |
|---------|------------------|-------------|
| `aACTIVE` | `:aactive` | Did you act as a professional agent? |
| `a1101` | `:a1101` | Total unique clients during reporting period |
| `a11301` | `:a11301` | Do you have PEP clients? |
| `a13501B` | `:a13501b` | Do you have VASP clients? |

Question lookup normalizes any casing to lowercase internally.

## Question Types

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
| `StructureParser` | `questionnaire_structure.yml` | Section/subsection hierarchy, question numbers, instructions |
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
│       ├── questionnaire_structure.yml
│       └── strix_*.xule
└── amsf_survey-yachting.gemspec
```

The `questionnaire_structure.yml` file maps the PDF structure to XBRL field IDs:

```yaml
parts:
  - name: "Inherent Risk"
    sections:
      - number: 1
        title: "Customer Risk"
        subsections:
          - number: "1.1"
            title: "Active in Reporting Cycle"
            questions:
              - field_id: "aACTIVE"
                question_number: 1
                instructions: "Activities subject to the law..."
              - field_id: "aACTIVEPS"
                question_number: 2
                instructions: "Purchases and Sales."
```

Question numbers are explicit and reset at each part boundary.

## Development

```bash
bundle install
bundle exec rspec
```

Test coverage: ~100% line coverage, 372 tests.

## License

MIT License
