# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ruby gem for Monaco AMSF (Autorité Monégasque de Supervision Financière) AML/CFT regulatory survey submissions. Generates XBRL instance documents for the Strix portal.

**Architecture**: Monorepo with industry-agnostic core gem (`amsf_survey/`) and pluggable industry taxonomies (`amsf_survey-{industry}/`).

## Commands

```bash
# Run tests (once gem structure exists)
bundle exec rspec

# Run single test file
bundle exec rspec spec/path/to/spec.rb

# Run specific test by line
bundle exec rspec spec/path/to/spec.rb:42

# Install dependencies
bundle install

# Build gem
gem build amsf_survey.gemspec
```

## Architecture

### Core Gem (`amsf_survey/`)

- `AmsfSurvey.questionnaire(industry:, year:)` - Access questionnaire structure
- `AmsfSurvey.build_submission(...)` - Create submission objects
- `AmsfSurvey.to_xbrl(submission)` - Generate XBRL XML

Key classes:
- `Questionnaire` - Container for parts/sections/questions, supports question lookup by lowercase ID, exposes `taxonomy_namespace`
- `Part` - Top-level grouping matching PDF structure (e.g., "Inherent Risk", "Controls", "Signatories"). Question numbers reset per part.
- `Section` - Logical grouping of subsections within a part
- `Subsection` - Groups questions within a section. Uses string numbers like "1.1", "1.2"
- `Question` - Primary unit combining XBRL metadata with PDF structure. Has `id` (lowercase for API), `xbrl_id` (original casing for XBRL), and `number` (explicit from YAML)
- `Field` - Internal XBRL metadata (type, labels, visibility rules). Not part of public API.
- `Submission` - Holds entity data with type casting, tracks completeness
- `Generator` - XBRL instance XML output with proper namespaces, context, and facts

### Object Hierarchy

```
Questionnaire
└── parts[]                    # Part objects
    ├── name                   # "Inherent Risk", "Controls", "Signatories"
    └── sections[]             # Section objects
        ├── number             # 1, 2, 3... (explicit from YAML)
        ├── title              # "Customer Risk"
        └── subsections[]      # Subsection objects
            ├── number         # "1.1", "1.2"... (string, explicit from YAML)
            ├── title          # "Active in Reporting Cycle"
            └── questions[]    # Question objects
                ├── number     # 1, 2, 3... (explicit, resets per Part)
                ├── id         # :aactive (lowercase for API)
                └── xbrl_id    # :aACTIVE (original casing for XBRL)
```

### Question ID Handling

Questions use a dual-ID system:
- `question.id` - Lowercase symbol for consistent API access (e.g., `:aactive`)
- `question.xbrl_id` - Original casing preserved for XBRL generation (e.g., `:aACTIVE`)

Question lookup normalizes input to lowercase:
```ruby
questionnaire.question(:aACTIVE)  # Returns question with id: :aactive
questionnaire.question(:AACTIVE)  # Same question
questionnaire.question(:aactive)  # Same question
```

### Taxonomy Parsers (`lib/amsf_survey/taxonomy/`)

- `SchemaParser` - Parses `.xsd` files for field types, valid values, and `targetNamespace`
- `LabelParser` - Parses `_lab.xml` files for French labels with HTML stripping
- `StructureParser` - Parses `questionnaire_structure.yml` for part/section/subsection hierarchy and explicit question numbers
- `XuleParser` - Parses `.xule` files for gate question dependencies
- `Loader` - Orchestrates all parsers to build a `Questionnaire`

### Registry

- `AmsfSurvey.register_plugin(industry:, taxonomy_path:)` - Register an industry plugin
- `AmsfSurvey.questionnaire(industry:, year:)` - Load questionnaire with lazy loading and caching
- `AmsfSurvey.registered_industries` - List registered industries
- `AmsfSurvey.supported_years(industry)` - List available years for an industry

### Industry Plugins (`amsf_survey-{industry}/`)

Minimal code (~10 lines) that registers taxonomy path:
```ruby
AmsfSurvey.register_plugin(
  industry: :real_estate,
  taxonomy_path: File.expand_path("../../taxonomies", __dir__)
)
```

Taxonomy files per year: `.xsd`, `_lab.xml`, `_def.xml`, `_pre.xml`, `_cal.xml`, `.xule`

### Validation

Validation is delegated to Arelle (external XBRL validator) which uses the authoritative XULE rules from the taxonomy. The gem provides:
- `submission.complete?` - Check if all visible questions are filled
- `submission.unanswered_questions` - List unfilled visible Question objects
- `submission.completion_percentage` - Progress indicator
- `submission.question_visible?(:id)` - Check if question should be shown in UI

### XBRL Generation

```ruby
# Basic generation
xml = AmsfSurvey.to_xbrl(submission)

# With options
xml = AmsfSurvey.to_xbrl(submission, pretty: true, include_empty: false)
```

Options:
- `pretty: true` - Output indented XML (default: false)
- `include_empty: false` - Omit nil fields (default: true - includes empty elements)

## Domain Context

XBRL taxonomy files in `docs/real_estate_taxonomy/` are the source of truth for question definitions. Questions are accessed using their XBRL element IDs (lowercase for API, original casing for XBRL output).

Gate questions control visibility: if a gate question is set to "Non", dependent questions become invisible and are not included in completeness checks.

## Speckit Workflow

This project uses Speckit for specification-driven development. Available slash commands:
- `/speckit.specify` - Create/update feature specification
- `/speckit.plan` - Generate implementation plan
- `/speckit.tasks` - Generate actionable task list
- `/speckit.implement` - Execute implementation tasks

Design document: `docs/plans/2025-12-21-amsf-survey-design.md`

## Active Technologies
- Ruby 3.2+ + RSpec (testing), SimpleCov (coverage), Rake (tasks)
- Nokogiri ~> 1.15 (XML parsing)
- File-based taxonomy loading from plugin gems

## Recent Changes
- 006-explicit-question-numbering: Added Part class for top-level hierarchy. Questionnaire now holds parts (Part → Section → Subsection → Question). Question numbers are explicit in YAML and reset per part. Real estate taxonomy has 322 questions across 3 parts: Inherent Risk (Q1-214), Controls (Q1-105), Signatories (Q1-3).
- 005-remove-semantic-indirection: Removed semantic_mappings.yml and Validator. Field IDs now use XBRL element names directly (lowercase for API, original for XBRL)
- 004-xbrl-generator: Added XBRL instance XML generation (Generator class, AmsfSurvey.to_xbrl method)
- 003-submission-validation: Added Submission class with type casting
- 002-taxonomy-loader: Added taxonomy loading infrastructure (Questionnaire, Section, Field, parsers, Registry.questionnaire())
- 001-monorepo-setup: Initial monorepo structure with core and plugin gems
