# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ruby gem for Monaco AMSF (Autorité Monégasque de Supervision Financière) AML/CFT regulatory survey submissions. Generates and validates XBRL instance documents for the Strix portal.

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
- `AmsfSurvey.validate(submission)` - Ruby-native validation (optional `:arelle` engine)
- `AmsfSurvey.to_xbrl(submission)` - Generate XBRL XML

Key classes:
- `Questionnaire` - Container for sections/fields, supports field lookup by ID or semantic name
- `Section` - Logical grouping of fields with visibility rules
- `Field` - Metadata (type, source_type, labels, visibility rules, gate dependencies)
- `Submission` - ActiveModel-based, holds entity data with type casting (future)
- `Validator` - Presence, sum checks, conditional logic, range validation (future)
- `Generator` - XBRL instance XML output (future)

### Taxonomy Parsers (`lib/amsf_survey/taxonomy/`)

- `SchemaParser` - Parses `.xsd` files for field types and valid values
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

Taxonomy files per year: `.xsd`, `_lab.xml`, `_def.xml`, `_pre.xml`, `_cal.xml`, `.xule`, `semantic_mappings.yml`

### Field Source Types

| Type | Meaning |
|------|---------|
| `:computed` | Derived from other fields via formula |
| `:prefillable` | Can be pre-populated from external data |
| `:entry_only` | Requires fresh input each submission |

### Validation Flow

1. Ruby-native validation (fast, no dependencies) - default
2. Arelle validation (optional) - authoritative XULE compliance check

## Domain Context

XBRL taxonomy files in `docs/real_estate_taxonomy/` are the source of truth for field definitions. The `semantic_mappings.yml` maps XBRL codes (e.g., `a1101`) to semantic Ruby field names.

Gate questions control field visibility: if `acted_as_professional_agent: false`, dependent fields become invisible and optional.

## Speckit Workflow

This project uses Speckit for specification-driven development. Available slash commands:
- `/speckit.specify` - Create/update feature specification
- `/speckit.plan` - Generate implementation plan
- `/speckit.tasks` - Generate actionable task list
- `/speckit.implement` - Execute implementation tasks

Design document: `docs/plans/2025-12-21-amsf-survey-design.md`

## Active Technologies
- Ruby 3.2+ + RSpec (testing), SimpleCov (coverage), Rake (tasks)
- Nokogiri ~> 1.15 (XML parsing), YAML (semantic mappings)
- File-based taxonomy loading from plugin gems

## Recent Changes
- 002-taxonomy-loader: Added taxonomy loading infrastructure (Questionnaire, Section, Field, parsers, Registry.questionnaire())
- 001-monorepo-setup: Initial monorepo structure with core and plugin gems
