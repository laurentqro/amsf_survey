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
- `Questionnaire` - Container for sections/fields, supports field lookup by lowercase ID, exposes `taxonomy_namespace`
- `Section` - Logical grouping of fields with visibility rules
- `Field` - Metadata (type, labels, visibility rules, gate dependencies). Has `id` (lowercase for API) and `xbrl_id` (original casing for XBRL)
- `Submission` - Holds entity data with type casting, tracks completeness
- `Generator` - XBRL instance XML output with proper namespaces, context, and facts

### Field ID Handling

Fields use a dual-ID system:
- `field.id` - Lowercase symbol for consistent API access (e.g., `:aactive`)
- `field.xbrl_id` - Original casing preserved for XBRL generation (e.g., `:aACTIVE`)

Field lookup normalizes input to lowercase:
```ruby
questionnaire.field(:aACTIVE)  # Returns field with id: :aactive
questionnaire.field(:AACTIVE)  # Same field
questionnaire.field(:aactive)  # Same field
```

### Taxonomy Parsers (`lib/amsf_survey/taxonomy/`)

- `SchemaParser` - Parses `.xsd` files for field types, valid values, and `targetNamespace`
- `LabelParser` - Parses `_lab.xml` files for French labels with HTML stripping
- `PresentationParser` - Parses `_pre.xml` files for section structure and ordering
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
- `submission.complete?` - Check if all visible fields are filled
- `submission.missing_fields` - List unfilled visible fields
- `submission.completion_percentage` - Progress indicator

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

XBRL taxonomy files in `docs/real_estate_taxonomy/` are the source of truth for field definitions. Fields are accessed using their XBRL element IDs (lowercase for API, original casing for XBRL output).

Gate questions control field visibility: if a gate field is set to "Non", dependent fields become invisible and are not included in completeness checks.

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
- 005-remove-semantic-indirection: Removed semantic_mappings.yml and Validator. Field IDs now use XBRL element names directly (lowercase for API, original for XBRL)
- 004-xbrl-generator: Added XBRL instance XML generation (Generator class, AmsfSurvey.to_xbrl method)
- 003-submission-validation: Added Submission class with type casting
- 002-taxonomy-loader: Added taxonomy loading infrastructure (Questionnaire, Section, Field, parsers, Registry.questionnaire())
- 001-monorepo-setup: Initial monorepo structure with core and plugin gems
