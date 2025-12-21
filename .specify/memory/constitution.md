<!--
Sync Impact Report
==================
- Version change: 0.0.0 → 1.0.0 (initial constitution)
- Modified principles: N/A (initial creation)
- Added sections:
  - Core Principles (6 principles derived from design document)
  - Technical Constraints (stack and dependencies)
  - Quality Gates (testing and validation requirements)
- Removed sections: None
- Templates requiring updates:
  - .specify/templates/plan-template.md ✅ (no updates needed - Constitution Check section compatible)
  - .specify/templates/spec-template.md ✅ (no updates needed - requirements structure compatible)
  - .specify/templates/tasks-template.md ✅ (no updates needed - phase structure compatible)
- Follow-up TODOs: None
==================
-->

# AMSF Survey Constitution

## Core Principles

### I. Consumer-Agnostic Core

The core gem (`amsf_survey`) MUST have zero knowledge of consuming applications.
- No references to CRM systems, CLI tools, web frameworks, or specific integrations
- Consumers interact through the public API only
- No serialization logic in the gem (belongs in API/presentation layer)

**Rationale**: Enables the gem to serve any consumer without modifications.

### II. Industry-Agnostic Architecture

The core gem MUST have zero knowledge of specific industries (real estate, yachting, etc.).
- Industry logic lives exclusively in plugin gems (`amsf_survey-{industry}`)
- Plugins register taxonomy paths; core loads and interprets them
- Core tests use synthetic fixtures, never real industry taxonomies

**Rationale**: Clean separation allows independent releases and prevents industry-specific logic from polluting the core.

### III. Taxonomy as Source of Truth

XBRL taxonomy files (`.xsd`, `_lab.xml`, `_def.xml`, `_pre.xml`, `_cal.xml`, `.xule`) MUST be the authoritative source for:
- Field definitions and types
- Labels (French regulatory labels)
- Validation rules (sum checks, conditional presence, ranges)
- Gate question dependencies

The `semantic_mappings.yml` file bridges XBRL codes to Ruby-friendly field names but MUST NOT introduce logic not derivable from taxonomy files.

**Rationale**: Single source of truth prevents drift between XBRL output and regulatory requirements.

### IV. Semantic Abstraction

Consumers MUST have no notion of XBRL internals.
- Public API uses semantic field names (`:total_unique_clients`), not XBRL codes (`a1101`)
- XBRL generation is an internal implementation detail
- Field metadata (labels, help text, input types) exposed through Ruby objects, not XML

**Rationale**: Enables form-driven UIs and business logic without XBRL expertise.

### V. Test-First Development (NON-NEGOTIABLE)

All features MUST follow TDD:
- Tests written and approved before implementation
- Tests MUST fail before implementation begins
- Red-Green-Refactor cycle strictly enforced

Coverage targets:
- 100% line and branch coverage for all classes
- Every XULE validation rule translated to Ruby tests
- All type/value casting combinations covered

**Rationale**: Regulatory compliance requires provable correctness.

### VI. Simplicity and YAGNI

Start with the minimum viable implementation:
- Single year support first, multi-year architecture ready but not implemented
- Ruby-native validation default, Arelle integration optional
- No premature abstractions or patterns

**Rationale**: Complexity must be justified by current, not hypothetical, requirements.

## Technical Constraints

**Language**: Ruby 3.2+
**Framework**: ActiveModel for Submission validations
**Dependencies**: Minimal (Nokogiri for XML parsing/generation)
**Testing**: RSpec with 100% coverage requirement
**Structure**: Monorepo with separate gemspecs per gem

## Quality Gates

### Pre-Implementation Gate

Before any feature work:
1. Consumer-agnostic check: Does this introduce consumer knowledge?
2. Industry-agnostic check: Does this introduce industry knowledge in core?
3. Taxonomy alignment check: Is the feature derivable from taxonomy files?

### Pre-Merge Gate

Before merging any PR:
1. All tests pass (`bundle exec rspec`)
2. Coverage >= 100% on changed code
3. No XBRL code references in public API
4. Constitution compliance verified

## Governance

This constitution supersedes all other development practices in this repository.

- Amendments require: documentation of change, rationale, and migration plan
- All code reviews MUST verify constitution compliance
- Complexity beyond these principles MUST be justified in writing
- Use `docs/plans/2025-12-21-amsf-survey-design.md` as the authoritative design reference

**Version**: 1.0.0 | **Ratified**: 2025-12-21 | **Last Amended**: 2025-12-21
