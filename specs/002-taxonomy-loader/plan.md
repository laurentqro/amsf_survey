# Implementation Plan: Taxonomy Loader

**Branch**: `002-taxonomy-loader` | **Date**: 2025-12-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-taxonomy-loader/spec.md`

## Summary

Implement a taxonomy loader that parses XBRL files (.xsd, _lab.xml, _pre.xml, .xule) and semantic_mappings.yml to build Questionnaire, Section, and Field objects. The loader provides a clean Ruby API for accessing survey structure, field metadata, and gate question dependencies, with lazy loading and caching for performance.

## Technical Context

**Language/Version**: Ruby 3.2+
**Primary Dependencies**: Nokogiri (XML parsing), YAML (semantic mappings)
**Storage**: File-based (taxonomy files in plugin gems)
**Testing**: RSpec with SimpleCov (100% coverage required)
**Target Platform**: Ruby gem (any Ruby runtime)
**Project Type**: Monorepo with core gem and plugin gems
**Performance Goals**: <2s initial load for 500+ fields, <10ms cached access
**Constraints**: No external network calls, memory-efficient parsing
**Scale/Scope**: ~500 fields per industry taxonomy, 3-5 sections per questionnaire

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Consumer-Agnostic Core | PASS | Loader provides data objects only, no consumer logic |
| II. Industry-Agnostic Architecture | PASS | Core parses any taxonomy; tests use synthetic fixtures |
| III. Taxonomy as Source of Truth | PASS | All field metadata derived from XBRL files |
| IV. Semantic Abstraction | PASS | Public API uses semantic names, XBRL codes internal |
| V. Test-First Development | PASS | TDD required per constitution |
| VI. Simplicity and YAGNI | PASS | Minimal parser set, gate rules only (no sum checks) |

**Pre-Implementation Gate**: PASSED - No violations detected.

## Project Structure

### Documentation (this feature)

```text
specs/002-taxonomy-loader/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
amsf_survey/                          # Core gem
├── lib/
│   └── amsf_survey/
│       ├── taxonomy/
│       │   ├── loader.rb             # Orchestrates parsing
│       │   ├── schema_parser.rb      # Parses .xsd
│       │   ├── label_parser.rb       # Parses _lab.xml
│       │   ├── presentation_parser.rb # Parses _pre.xml
│       │   └── xule_parser.rb        # Parses .xule
│       ├── questionnaire.rb          # Container for sections/fields
│       ├── section.rb                # Field grouping
│       ├── field.rb                  # Field metadata
│       └── registry.rb               # Updated with questionnaire()
├── spec/
│   ├── amsf_survey/
│   │   ├── taxonomy/
│   │   │   ├── loader_spec.rb
│   │   │   ├── schema_parser_spec.rb
│   │   │   ├── label_parser_spec.rb
│   │   │   ├── presentation_parser_spec.rb
│   │   │   └── xule_parser_spec.rb
│   │   ├── questionnaire_spec.rb
│   │   ├── section_spec.rb
│   │   └── field_spec.rb
│   └── fixtures/
│       └── taxonomies/
│           └── test_industry/
│               └── 2025/
│                   ├── test_survey.xsd
│                   ├── test_survey_lab.xml
│                   ├── test_survey_pre.xml
│                   ├── test_survey.xule
│                   └── semantic_mappings.yml

amsf_survey-real_estate/              # Plugin gem (add semantic_mappings.yml)
└── taxonomies/
    └── 2025/
        └── semantic_mappings.yml     # Maps XBRL codes to semantic names
```

**Structure Decision**: Monorepo structure established in 001-monorepo-setup. This feature adds taxonomy/ subdirectory for parsers, data model classes at lib/amsf_survey/ level, and synthetic test fixtures.

## Complexity Tracking

No violations requiring justification.
