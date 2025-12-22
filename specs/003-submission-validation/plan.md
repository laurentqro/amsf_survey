# Implementation Plan: Submission & Validation

**Branch**: `003-submission-validation` | **Date**: 2025-12-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-submission-validation/spec.md`

## Summary

Implement the Submission class for holding survey response data with automatic type casting, completeness tracking, and the Validator for checking presence, sum checks, conditional logic, and range validation. The Submission integrates with ActiveModel for validation semantics while the Validator provides domain-specific XBRL validation rules.

## Technical Context

**Language/Version**: Ruby 3.2+
**Primary Dependencies**: ActiveModel (validations, attributes), existing Questionnaire/Field classes from Phase 2
**Storage**: N/A (in-memory, no persistence - consumer responsibility)
**Testing**: RSpec with SimpleCov, 100% line coverage requirement
**Target Platform**: Ruby gem (cross-platform)
**Project Type**: Single gem (monorepo with plugins)
**Performance Goals**: <10ms submission creation, <50ms validation for 500 fields
**Constraints**: No external network calls, Ruby-native validation only (Arelle deferred)
**Scale/Scope**: ~150-500 fields per questionnaire, single entity per submission

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Consumer-Agnostic Core | ✅ PASS | Submission is a generic container; no CRM/CLI/web knowledge |
| II. Industry-Agnostic Architecture | ✅ PASS | Submission works with any registered industry; uses questionnaire API |
| III. Taxonomy as Source of Truth | ✅ PASS | Validation rules derived from Field metadata (from taxonomy) |
| IV. Semantic Abstraction | ✅ PASS | Field names are semantic; XBRL codes hidden internally |
| V. Test-First Development | ✅ WILL COMPLY | Tests written before implementation per constitution |
| VI. Simplicity and YAGNI | ✅ PASS | Starting with basic validation; no computed formulas yet |

**Pre-Implementation Gate**: ✅ PASSED
- No consumer knowledge introduced
- No industry knowledge in core
- All features derivable from taxonomy (field types, visibility, valid_values)

## Project Structure

### Documentation (this feature)

```text
specs/003-submission-validation/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
amsf_survey/
├── lib/
│   └── amsf_survey/
│       ├── submission.rb          # NEW: Survey response container
│       ├── validator.rb           # NEW: Validation engine
│       ├── validation_result.rb   # NEW: Validation outcome
│       ├── validation_error.rb    # NEW: Individual validation issue
│       ├── type_caster.rb         # NEW: String-to-type conversion
│       ├── field.rb               # EXISTING: Add cast() method
│       ├── questionnaire.rb       # EXISTING: No changes needed
│       ├── section.rb             # EXISTING: No changes needed
│       ├── registry.rb            # EXISTING: Add build_submission helper
│       ├── errors.rb              # EXISTING: Add new error types
│       └── taxonomy/              # EXISTING: No changes needed
│           ├── loader.rb
│           ├── schema_parser.rb
│           ├── label_parser.rb
│           ├── presentation_parser.rb
│           └── xule_parser.rb
│
├── spec/
│   └── amsf_survey/
│       ├── submission_spec.rb           # NEW
│       ├── validator_spec.rb            # NEW
│       ├── validation_result_spec.rb    # NEW
│       ├── validation_error_spec.rb     # NEW
│       ├── type_caster_spec.rb          # NEW
│       └── integration/
│           └── submission_validation_spec.rb  # NEW
```

**Structure Decision**: Single gem structure following existing Phase 2 patterns. New files added to `lib/amsf_survey/` with corresponding specs in `spec/amsf_survey/`.

## Complexity Tracking

> No violations - all implementation follows constitution principles.

| Principle | Simplicity Check |
|-----------|------------------|
| ActiveModel dependency | Justified: provides standard validation patterns without custom framework |
| Separate Validator class | Justified: keeps Submission focused on data, Validator on rules |
| TypeCaster extraction | Justified: single responsibility, reusable across field operations |
