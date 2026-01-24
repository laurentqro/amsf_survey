# Tasks: Remove Semantic Name Indirection

**Input**: Design documents from `/specs/005-remove-semantic-indirection/`
**Prerequisites**: plan.md, spec.md, data-model.md, quickstart.md

**Tests**: Tests are included per constitution requirement (Test-First Development).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Core gem**: `amsf_survey/lib/amsf_survey/`
- **Core specs**: `amsf_survey/spec/`
- **Industry plugin**: `amsf_survey-real_estate/`
- **Test fixtures**: `amsf_survey/spec/fixtures/`

---

## Phase 1: Setup (Cleanup & Removal)

**Purpose**: Remove deprecated files and functionality before modifying core classes

- [ ] T001 Delete validator.rb in amsf_survey/lib/amsf_survey/validator.rb
- [ ] T002 [P] Delete validator_spec.rb in amsf_survey/spec/validator_spec.rb
- [ ] T003 [P] Delete semantic_mappings.yml in amsf_survey/spec/fixtures/taxonomies/test_industry/2025/semantic_mappings.yml
- [ ] T004 [P] Delete semantic_mappings.yml in amsf_survey-real_estate/taxonomies/2025/semantic_mappings.yml
- [ ] T005 Remove AmsfSurvey.validate method in amsf_survey/lib/amsf_survey.rb

**Checkpoint**: All deprecated files removed. Core classes ready for modification.

---

## Phase 2: Foundational (Field Class Changes)

**Purpose**: Core Field class changes that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Add xbrl_id attribute and lowercase id accessor in amsf_survey/lib/amsf_survey/field.rb
- [ ] T007 Remove name attribute from Field in amsf_survey/lib/amsf_survey/field.rb
- [ ] T008 Remove source_type attribute and predicates (required?, computed?, prefillable?, entry_only?) in amsf_survey/lib/amsf_survey/field.rb
- [ ] T009 Update Loader to stop loading semantic_mappings.yml in amsf_survey/lib/amsf_survey/taxonomy/loader.rb
- [ ] T010 Update Loader to pass original ID as xbrl_id in amsf_survey/lib/amsf_survey/taxonomy/loader.rb
- [ ] T011 Update field_spec.rb for new Field API in amsf_survey/spec/field_spec.rb

**Checkpoint**: Field class API complete. User story implementation can now begin.

---

## Phase 3: User Story 1 - CRM Developer Uses Field IDs Directly (Priority: P1) 🎯 MVP

**Goal**: Developers can access fields and create submissions using lowercase XBRL IDs directly

**Independent Test**: Create a submission with field IDs, verify field access works with lowercase IDs

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T012 [P] [US1] Add test: field lookup with lowercase ID returns correct Field in amsf_survey/spec/questionnaire_spec.rb
- [ ] T013 [P] [US1] Add test: field lookup normalizes mixed-case input to lowercase in amsf_survey/spec/questionnaire_spec.rb
- [ ] T014 [P] [US1] Add test: submission data keyed by lowercase IDs in amsf_survey/spec/submission_spec.rb
- [ ] T015 [P] [US1] Add test: submission accessor normalizes input to lowercase in amsf_survey/spec/submission_spec.rb

### Implementation for User Story 1

- [ ] T016 [US1] Update Questionnaire.field() to normalize input to lowercase in amsf_survey/lib/amsf_survey/questionnaire.rb
- [ ] T017 [US1] Update Questionnaire.build_field_index to use lowercase IDs only in amsf_survey/lib/amsf_survey/questionnaire.rb
- [ ] T018 [US1] Remove computed_fields, prefillable_fields, entry_only_fields methods in amsf_survey/lib/amsf_survey/questionnaire.rb
- [ ] T019 [US1] Update Submission.[] to normalize input to lowercase in amsf_survey/lib/amsf_survey/submission.rb
- [ ] T020 [US1] Update Submission.[]= to normalize input to lowercase in amsf_survey/lib/amsf_survey/submission.rb
- [ ] T021 [US1] Update Submission.initialize to normalize data keys to lowercase in amsf_survey/lib/amsf_survey/submission.rb
- [ ] T022 [US1] Update remaining submission_spec.rb tests to use field IDs in amsf_survey/spec/submission_spec.rb
- [ ] T023 [US1] Update remaining questionnaire_spec.rb tests to use field IDs in amsf_survey/spec/questionnaire_spec.rb

**Checkpoint**: User Story 1 complete. Developers can access fields and create submissions using lowercase IDs.

---

## Phase 4: User Story 2 - XBRL Output Preserves Original Casing (Priority: P1)

**Goal**: XBRL generation uses original element casing for regulatory compliance

**Independent Test**: Generate XBRL from submission with mixed-case field, verify element name matches original taxonomy

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T024 [P] [US2] Add test: XBRL element names use original casing (xbrl_id) in amsf_survey/spec/generator_spec.rb
- [ ] T025 [P] [US2] Add test: mixed-case fields generate correct element names in amsf_survey/spec/generator_spec.rb

### Implementation for User Story 2

- [ ] T026 [US2] Update Generator.build_fact to use field.xbrl_id for element names in amsf_survey/lib/amsf_survey/generator.rb
- [ ] T027 [US2] Update remaining generator_spec.rb tests to use field IDs in amsf_survey/spec/generator_spec.rb

**Checkpoint**: User Story 2 complete. XBRL output uses original taxonomy casing.

---

## Phase 5: User Story 3 - Progress Tracking for Survey Completion (Priority: P2)

**Goal**: CRM can show users their progress through visible fields

**Independent Test**: Create partially-filled submission, verify complete? and missing_fields work correctly

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T028 [P] [US3] Add test: complete? returns false when visible fields are unfilled in amsf_survey/spec/submission_spec.rb
- [ ] T029 [P] [US3] Add test: missing_fields returns list of unfilled visible field IDs in amsf_survey/spec/submission_spec.rb
- [ ] T030 [P] [US3] Add test: hidden fields (gate=false) not counted in missing_fields in amsf_survey/spec/submission_spec.rb

### Implementation for User Story 3

- [ ] T031 [US3] Update complete? to check all visible fields have values in amsf_survey/lib/amsf_survey/submission.rb
- [ ] T032 [US3] Update missing_fields to return lowercase field IDs in amsf_survey/lib/amsf_survey/submission.rb
- [ ] T033 [US3] Verify gate visibility logic works with lowercase IDs in amsf_survey/lib/amsf_survey/submission.rb

**Checkpoint**: All user stories complete. Progress tracking works with lowercase IDs.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and documentation updates

- [ ] T034 [P] Update test fixtures to use field IDs instead of semantic names in amsf_survey/spec/fixtures/
- [ ] T035 [P] Run full test suite and verify 100% coverage in amsf_survey/
- [ ] T036 [P] Update CLAUDE.md to remove references to semantic_mappings.yml
- [ ] T037 Amend constitution Principle IV in .specify/memory/constitution.md
- [ ] T038 Run quickstart.md validation examples manually

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1 and US2 can proceed in parallel (different files)
  - US3 depends on Submission changes from US1
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories (different file: generator.rb)
- **User Story 3 (P2)**: Depends on US1 Submission changes (T019-T021) for lowercase key handling

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Update specs after implementation to ensure they pass
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002, T003, T004)
- All Foundational tasks are sequential (same file: field.rb)
- US1 tests (T012-T015) can run in parallel
- US2 tests (T024-T025) can run in parallel
- US3 tests (T028-T030) can run in parallel
- US1 and US2 can be implemented in parallel (different files)
- Polish tasks marked [P] can run in parallel (T034, T035, T036)

---

## Parallel Example: User Story 1 + User Story 2

```bash
# After Foundational phase completes, launch in parallel:

# US1: Questionnaire and Submission changes
Task: T012-T015 (tests in parallel)
Task: T016-T023 (implementation sequential)

# US2: Generator changes (different file, no conflict)
Task: T024-T025 (tests in parallel)
Task: T026-T027 (implementation sequential)
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup (remove deprecated files)
2. Complete Phase 2: Foundational (Field class changes)
3. Complete Phase 3: User Story 1 (field lookup by ID)
4. Complete Phase 4: User Story 2 (XBRL casing)
5. **STOP and VALIDATE**: Test XBRL generation with real taxonomy
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Core API ready
2. Add User Story 1 → Test field access → Deploy (can create submissions)
3. Add User Story 2 → Test XBRL output → Deploy (can submit to Strix)
4. Add User Story 3 → Test progress tracking → Deploy (full feature)
5. Polish → Final cleanup → Release

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- This is primarily a SUBTRACTIVE feature (removing code and files)
