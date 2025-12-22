# Tasks: Submission & Validation

**Input**: Design documents from `/specs/003-submission-validation/`
**Prerequisites**: plan.md (✓), spec.md (✓), research.md (✓), data-model.md (✓), quickstart.md (✓)

**Tests**: Required per constitution (Test-First Development) and CLAUDE.md (100% line coverage)

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Source**: `lib/amsf_survey/`
- **Tests**: `spec/amsf_survey/`
- **Integration Tests**: `spec/amsf_survey/integration/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add new error types and prepare gem structure for submission/validation classes

- [ ] T001 Add UnknownFieldError and TaxonomyLoadError to lib/amsf_survey/errors.rb
- [ ] T002 Create spec/amsf_survey/errors_spec.rb with tests for new error types

---

## Phase 2: Foundational (TypeCaster Module)

**Purpose**: Type casting is used by Submission when setting values - MUST be complete first

**⚠️ CRITICAL**: Submission#[]= depends on TypeCaster - no submission work can begin without this

- [ ] T003 [P] Create spec/amsf_survey/type_caster_spec.rb with tests for all type conversions
- [ ] T004 Implement TypeCaster module in lib/amsf_survey/type_caster.rb
- [ ] T005 Add Field#cast method that delegates to TypeCaster in lib/amsf_survey/field.rb

**Checkpoint**: TypeCaster ready - Submission implementation can now begin

---

## Phase 3: User Story 1 & 4 - Create and Populate a Submission with Type Casting (Priority: P1) 🎯 MVP

**Goal**: Create Submission container that stores field values with automatic type casting

**Independent Test**: Create submission with sample data, verify values stored, type-cast correctly, accessible

### Tests for User Stories 1 & 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T006 [P] [US1] Create spec/amsf_survey/submission_spec.rb with initialization tests
- [ ] T007 [P] [US1] Add tests for bracket notation get/set with type casting
- [ ] T008 [P] [US1] Add tests for unknown field error handling
- [ ] T009 [P] [US1] Add tests for questionnaire access

### Implementation for User Stories 1 & 4

- [ ] T010 [US1] Create Submission class with ActiveModel::Model in lib/amsf_survey/submission.rb
- [ ] T011 [US1] Implement Submission#[]= with type casting via Field#cast
- [ ] T012 [US1] Implement Submission#[] for reading values
- [ ] T013 [US1] Implement Submission#questionnaire for accessing associated questionnaire
- [ ] T014 [US1] Implement Submission#data for raw data hash access
- [ ] T015 [US1] Add build_submission helper to lib/amsf_survey/registry.rb
- [ ] T016 [US1] Add AmsfSurvey.build_submission facade method in lib/amsf_survey.rb
- [ ] T017 [US1] Require submission.rb in lib/amsf_survey.rb

**Checkpoint**: Submission creation and value setting works with type casting - MVP complete

---

## Phase 4: User Story 2 - Track Submission Completeness (Priority: P2)

**Goal**: Track which required fields are missing and calculate completion percentage

**Independent Test**: Create partially-filled submission, verify completeness metrics

### Tests for User Story 2

- [ ] T018 [P] [US2] Create tests for Submission#complete? in spec/amsf_survey/submission_spec.rb
- [ ] T019 [P] [US2] Create tests for Submission#missing_fields including gate-aware logic
- [ ] T020 [P] [US2] Create tests for Submission#completion_percentage
- [ ] T021 [P] [US2] Create tests for Submission#missing_entry_only_fields

### Implementation for User Story 2

- [ ] T022 [US2] Implement Submission#complete? in lib/amsf_survey/submission.rb
- [ ] T023 [US2] Implement Submission#missing_fields with gate-aware visibility
- [ ] T024 [US2] Implement Submission#completion_percentage
- [ ] T025 [US2] Implement Submission#missing_entry_only_fields

**Checkpoint**: Completeness tracking works - users can see progress

---

## Phase 5: User Story 3 - Validate Submission Data (Priority: P2)

**Goal**: Validate submission data and return structured results with errors/warnings

**Independent Test**: Create submissions with valid/invalid data, verify validation results

### Tests for User Story 3

- [ ] T026 [P] [US3] Create spec/amsf_survey/validation_error_spec.rb
- [ ] T027 [P] [US3] Create spec/amsf_survey/validation_result_spec.rb
- [ ] T028 [P] [US3] Create spec/amsf_survey/validator_spec.rb with presence tests
- [ ] T029 [P] [US3] Add tests for range validation in validator_spec.rb
- [ ] T030 [P] [US3] Add tests for enum validation in validator_spec.rb
- [ ] T031 [P] [US3] Add tests for conditional validation in validator_spec.rb

### Implementation for User Story 3

- [ ] T032 [P] [US3] Create ValidationError class in lib/amsf_survey/validation_error.rb
- [ ] T033 [P] [US3] Create ValidationResult class in lib/amsf_survey/validation_result.rb
- [ ] T034 [US3] Create Validator module in lib/amsf_survey/validator.rb with validate method
- [ ] T035 [US3] Implement Validator.validate_presence for required field checks
- [ ] T036 [US3] Implement Validator.validate_ranges for min/max checks
- [ ] T037 [US3] Implement Validator.validate_enums for valid value checks
- [ ] T038 [US3] Implement Validator.validate_conditionals for gate-dependent checks
- [ ] T039 [US3] Add AmsfSurvey.validate(submission) facade method in lib/amsf_survey.rb
- [ ] T040 [US3] Require validation classes in lib/amsf_survey.rb

**Checkpoint**: Validation works - data quality assurance available

---

## Phase 6: User Story 5 - Validation Result Details (Priority: P3)

**Goal**: Ensure validation errors include detailed, actionable information

**Independent Test**: Validate invalid data, inspect error structure for completeness

### Tests for User Story 5

- [ ] T041 [P] [US5] Add tests for sum check error context in validator_spec.rb
- [ ] T042 [P] [US5] Add tests for range error context in validator_spec.rb
- [ ] T043 [P] [US5] Add tests for warnings vs errors separation in validation_result_spec.rb

### Implementation for User Story 5

- [ ] T044 [US5] Add context hash with expected/actual to sum check errors
- [ ] T045 [US5] Add context hash with value/min/max to range errors
- [ ] T046 [US5] Implement ValidationResult#error_count and #warning_count
- [ ] T047 [US5] Add ValidationError#to_h and #to_s methods

**Checkpoint**: Detailed validation errors available - debugging enabled

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Integration tests, edge cases, and documentation validation

- [ ] T048 Create spec/amsf_survey/integration/submission_validation_spec.rb
- [ ] T049 Add edge case tests (nil values, empty strings, missing industry)
- [ ] T050 Validate against quickstart.md usage examples
- [ ] T051 Run full test suite and verify 100% line coverage
- [ ] T052 Update CLAUDE.md if any command patterns changed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phases 3-6)**: All depend on Foundational phase
  - US1+US4 must complete before US2 (completeness uses Submission)
  - US3 can run in parallel with US2 (independent validation logic)
  - US5 depends on US3 (enhances validation errors)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational: TypeCaster)
    ↓
Phase 3 (US1+US4: Submission MVP) ─────────────────────┐
    ↓                                                   │
Phase 4 (US2: Completeness) ←─ depends on Submission   │
    ↓                                                   ↓
    └──────────────────────────────────────→ Phase 5 (US3: Validation)
                                                   ↓
                                             Phase 6 (US5: Details)
                                                   ↓
                                             Phase 7 (Polish)
```

### Within Each User Story

1. Tests MUST be written and FAIL before implementation
2. Models/classes before integration
3. Core implementation before convenience methods
4. Story complete before moving to next priority
5. Commit after each task or logical group

### Parallel Opportunities

- Phase 2: T003 can run while T001/T002 complete
- Phase 3: All test tasks (T006-T009) can run in parallel
- Phase 4: All test tasks (T018-T021) can run in parallel
- Phase 5: All test tasks (T026-T031) and class creation (T032-T033) can run in parallel
- Phase 6: All test tasks (T041-T043) can run in parallel

---

## Parallel Example: User Story 3

```bash
# Launch all tests for User Story 3 together:
Task: "Create spec/amsf_survey/validation_error_spec.rb"
Task: "Create spec/amsf_survey/validation_result_spec.rb"
Task: "Create spec/amsf_survey/validator_spec.rb with presence tests"
Task: "Add tests for range validation in validator_spec.rb"
Task: "Add tests for enum validation in validator_spec.rb"
Task: "Add tests for conditional validation in validator_spec.rb"

# Launch value objects together:
Task: "Create ValidationError class in lib/amsf_survey/validation_error.rb"
Task: "Create ValidationResult class in lib/amsf_survey/validation_result.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 4 Only)

1. Complete Phase 1: Setup (errors)
2. Complete Phase 2: Foundational (TypeCaster)
3. Complete Phase 3: User Stories 1 & 4 (Submission + Type Casting)
4. **STOP and VALIDATE**: Test Submission independently
5. Deploy/demo if ready - consumers can create and populate submissions

### Incremental Delivery

1. Complete Setup + Foundational → TypeCaster ready
2. Add US1+US4 → Test independently → MVP! (Submission works)
3. Add US2 → Test independently → Completeness tracking
4. Add US3 → Test independently → Validation available
5. Add US5 → Test independently → Detailed errors
6. Polish → Integration tests, documentation

### Suggested MVP Scope

**For MVP, complete only through Phase 3** (T001-T017):
- Submissions can be created
- Values can be set with type casting
- Questionnaire accessible
- Unknown fields raise errors

This delivers a working data container that consumers can immediately use.

---

## Notes

- All tests written before implementation per constitution (Test-First Development)
- 100% line coverage required per CLAUDE.md
- Sum check validation noted in spec but formulas not yet in taxonomy - implement structure, leave formula extraction for future
- Range validation uses min/max from Field if available (may be nil initially)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
