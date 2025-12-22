# Implementation Plan: XBRL Generator

**Branch**: `004-xbrl-generator` | **Date**: 2025-12-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-xbrl-generator/spec.md`

## Summary

Generate XBRL instance XML documents from validated `Submission` objects for upload to the Monaco AMSF Strix portal. Uses Nokogiri Builder DSL for XML construction with proper namespace handling, context generation, and field type formatting.

## Technical Context

**Language/Version**: Ruby 3.2+
**Primary Dependencies**: Nokogiri ~> 1.15 (already in gemspec)
**Storage**: N/A (generates XML string, no persistence)
**Testing**: RSpec with 100% coverage requirement
**Target Platform**: Ruby gem (cross-platform)
**Project Type**: Monorepo gem
**Performance Goals**: <100ms generation for 500 fields
**Constraints**: Must produce Strix-compatible XBRL 2.1 instance documents
**Scale/Scope**: ~95 fields per submission (real estate taxonomy)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Implementation Gate

| Check | Status | Notes |
|-------|--------|-------|
| Consumer-agnostic | ✅ PASS | Generator has no knowledge of CRM/CLI/web - outputs string |
| Industry-agnostic | ✅ PASS | Uses `questionnaire.taxonomy_namespace` - no industry logic in core |
| Taxonomy as source of truth | ✅ PASS | Namespace extracted from XSD; field IDs are XBRL codes |

### Post-Design Gate (Re-evaluated)

| Check | Status | Notes |
|-------|--------|-------|
| Consumer-agnostic | ✅ PASS | `AmsfSurvey.to_xbrl(submission)` returns string - caller handles I/O |
| Industry-agnostic | ✅ PASS | No industry-specific code; namespace from questionnaire |
| Taxonomy as source of truth | ✅ PASS | Field types, IDs, visibility all from taxonomy |
| Test-first | ✅ READY | Tests defined in spec acceptance scenarios |
| YAGNI | ✅ PASS | No multi-period, no XBRL-JSON, no Arelle - just core generation |

## Project Structure

### Documentation (this feature)

```text
specs/004-xbrl-generator/
├── plan.md              # This file
├── research.md          # Phase 0 output - XBRL patterns research
├── data-model.md        # Phase 1 output - Generator entity design
├── quickstart.md        # Phase 1 output - Usage examples
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
amsf_survey/
├── lib/
│   └── amsf_survey/
│       ├── generator.rb           # NEW: XBRL Generator class
│       ├── registry.rb            # MODIFY: Add to_xbrl method
│       ├── questionnaire.rb       # MODIFY: Add taxonomy_namespace attr
│       └── taxonomy/
│           └── schema_parser.rb   # MODIFY: Extract targetNamespace
│
└── spec/
    └── amsf_survey/
        ├── generator_spec.rb      # NEW: Generator unit tests
        └── integration/
            └── xbrl_generation_spec.rb  # NEW: End-to-end tests
```

**Structure Decision**: Single Ruby gem with new `Generator` class. Follows existing pattern of domain classes in `lib/amsf_survey/` with corresponding specs.

## Complexity Tracking

No constitution violations. All design decisions follow established patterns.

## Key Design Decisions

### 1. Taxonomy Namespace Source

**Decision**: Extract from XSD `targetNamespace` during taxonomy loading.

**Rationale**: Maintains taxonomy as single source of truth per Constitution III. The namespace is already defined in the XSD file.

**Implementation**: Enhance `SchemaParser` to capture `targetNamespace`, store in `Questionnaire`.

### 2. Boolean Value Formatting

**Decision**: Convert Ruby `true`/`false` back to French `"Oui"`/`"Non"` during XBRL generation.

**Rationale**: Strix portal expects original French values. TypeCaster stores booleans internally; Generator handles presentation.

### 3. Gate Visibility

**Decision**: Generator checks `field.visible?(data)` and excludes hidden fields.

**Rationale**: XBRL output should only contain answers to visible questions. Hidden fields are not applicable.

### 4. Validation Responsibility

**Decision**: Generator does NOT validate. Caller must validate separately.

**Rationale**: Separation of concerns. Allows preview generation of incomplete submissions.

## Dependencies

| Dependency | Version | Purpose | Status |
|------------|---------|---------|--------|
| Nokogiri | ~> 1.15 | XML Builder DSL | Already installed |

No new dependencies required.

## Artifacts Generated

| Artifact | Path | Status |
|----------|------|--------|
| Research | `specs/004-xbrl-generator/research.md` | ✅ Complete |
| Data Model | `specs/004-xbrl-generator/data-model.md` | ✅ Complete |
| Quickstart | `specs/004-xbrl-generator/quickstart.md` | ✅ Complete |
| Tasks | `specs/004-xbrl-generator/tasks.md` | ⏳ Next (`/speckit.tasks`) |
