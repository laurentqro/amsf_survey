# Implementation Plan: Monorepo Structure Setup

**Branch**: `001-monorepo-setup` | **Date**: 2025-12-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-monorepo-setup/spec.md`

## Summary

Set up the monorepo structure for the AMSF Survey gem ecosystem. This includes creating the core gem (`amsf_survey`) with a plugin registry, and the real estate industry plugin (`amsf_survey-real_estate`) that auto-registers on load. Both gems will have RSpec test infrastructure with SimpleCov coverage.

## Technical Context

**Language/Version**: Ruby 3.2+
**Primary Dependencies**: RSpec (testing), SimpleCov (coverage), Rake (tasks)
**Storage**: N/A (file-based taxonomy loading in future phases)
**Testing**: RSpec with SimpleCov for 100% coverage
**Target Platform**: Ruby runtime (cross-platform gem)
**Project Type**: Monorepo with multiple gems
**Performance Goals**: Core gem loads in under 100ms
**Constraints**: No runtime dependencies for core gem in this phase
**Scale/Scope**: 2 gems (core + 1 plugin), ~10 public API methods

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Consumer-Agnostic Core | PASS | Core gem has no consumer knowledge |
| II. Industry-Agnostic Architecture | PASS | Industry logic isolated in plugin gems |
| III. Taxonomy as Source of Truth | N/A | Taxonomy loading not in this phase |
| IV. Semantic Abstraction | N/A | No XBRL exposure in this phase |
| V. Test-First Development | PASS | RSpec/SimpleCov infrastructure established |
| VI. Simplicity and YAGNI | PASS | Minimal registry only, no premature abstractions |

**Pre-Implementation Gate**:
1. Consumer-agnostic check: PASS - No CRM/CLI references
2. Industry-agnostic check: PASS - Core has no real estate knowledge
3. Taxonomy alignment check: N/A - Taxonomy loading in future phase

## Project Structure

### Documentation (this feature)

```text
specs/001-monorepo-setup/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── checklists/
    └── requirements.md  # Spec validation checklist
```

### Source Code (repository root)

```text
amsf_survey/                           # Core gem
├── lib/
│   ├── amsf_survey.rb                 # Main entry point
│   └── amsf_survey/
│       ├── version.rb                 # Gem version
│       └── registry.rb                # Plugin registry
├── spec/
│   ├── spec_helper.rb                 # RSpec configuration
│   ├── amsf_survey_spec.rb            # Core module specs
│   └── amsf_survey/
│       └── registry_spec.rb           # Registry specs
├── amsf_survey.gemspec
├── Gemfile
├── Rakefile
└── README.md

amsf_survey-real_estate/               # Industry plugin
├── lib/
│   └── amsf_survey/
│       └── real_estate.rb             # Auto-registration
├── taxonomies/
│   └── 2025/
│       ├── strix_*.xsd                # Taxonomy files
│       ├── strix_*_lab.xml
│       ├── strix_*_def.xml
│       ├── strix_*_pre.xml
│       ├── strix_*_cal.xml
│       └── strix_*.xule
├── spec/
│   ├── spec_helper.rb
│   └── amsf_survey/
│       └── real_estate_spec.rb        # Registration specs
├── amsf_survey-real_estate.gemspec
├── Gemfile
├── Rakefile
└── README.md
```

**Structure Decision**: Monorepo with separate gem directories per constitution requirement. Each gem is independently buildable and testable.

## Complexity Tracking

> No violations - structure follows constitution exactly.
