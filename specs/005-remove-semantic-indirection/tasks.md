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

- [x] T001 Delete validator.rb in amsf_survey/lib/amsf_survey/validator.rb
- [x] T002 [P] Delete validator_spec.rb in amsf_survey/spec/validator_spec.rb
- [x] T003 [P] Delete semantic_mappings.yml in amsf_survey/spec/fixtures/taxonomies/test_industry/2025/semantic_mappings.yml
- [x] T004 [P] Delete semantic_mappings.yml in amsf_survey-real_estate/taxonomies/2025/semantic_mappings.yml
- [x] T005 Remove AmsfSurvey.validate method in amsf_survey/lib/amsf_survey.rb

**Checkpoint**: All deprecated files removed. Core classes ready for modification. ✅

---

## Phase 2: Foundational (Field Class Changes)

**Purpose**: Core Field class changes that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 Add xbrl_id attribute and lowercase id accessor in amsf_survey/lib/amsf_survey/field.rb
- [x] T007 Remove name attribute from Field in amsf_survey/lib/amsf_survey/field.rb
- [x] T008 Remove source_type attribute and predicates (required?, computed?, prefillable?, entry_only?) in amsf_survey/lib/amsf_survey/field.rb
- [x] T009 Update Loader to stop loading semantic_mappings.yml in amsf_survey/lib/amsf_survey/taxonomy/loader.rb
- [x] T010 Update Loader to pass original ID as xbrl_id in amsf_survey/lib/amsf_survey/taxonomy/loader.rb
- [x] T011 Update field_spec.rb for new Field API in amsf_survey/spec/field_spec.rb

**Checkpoint**: Field class API complete. User story implementation can now begin. ✅

---

## Phase 3: User Story 1 - CRM Developer Uses Field IDs Directly (Priority: P1) 🎯 MVP

**Goal**: Developers can access fields and create submissions using lowercase XBRL IDs directly

**Independent Test**: Create a submission with field IDs, verify field access works with lowercase IDs

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T012 [P] [US1] Add test: field lookup with lowercase ID returns correct Field in amsf_survey/spec/questionnaire_spec.rb
- [x] T013 [P] [US1] Add test: field lookup normalizes mixed-case input to lowercase in amsf_survey/spec/questionnaire_spec.rb
- [x] T014 [P] [US1] Add test: submission data keyed by lowercase IDs in amsf_survey/spec/submission_spec.rb
- [x] T015 [P] [US1] Add test: submission accessor normalizes input to lowercase in amsf_survey/spec/submission_spec.rb

### Implementation for User Story 1

- [x] T016 [US1] Update Questionnaire.field() to normalize input to lowercase in amsf_survey/lib/amsf_survey/questionnaire.rb
- [x] T017 [US1] Update Questionnaire.build_field_index to use lowercase IDs only in amsf_survey/lib/amsf_survey/questionnaire.rb
- [x] T018 [US1] Remove computed_fields, prefillable_fields, entry_only_fields methods in amsf_survey/lib/amsf_survey/questionnaire.rb
- [x] T019 [US1] Update Submission.[] to normalize input to lowercase in amsf_survey/lib/amsf_survey/submission.rb
- [x] T020 [US1] Update Submission.[]= to normalize input to lowercase in amsf_survey/lib/amsf_survey/submission.rb
- [x] T021 [US1] Update Submission.initialize to normalize data keys to lowercase in amsf_survey/lib/amsf_survey/submission.rb
- [x] T022 [US1] Update remaining submission_spec.rb tests to use field IDs in amsf_survey/spec/submission_spec.rb
- [x] T023 [US1] Update remaining questionnaire_spec.rb tests to use field IDs in amsf_survey/spec/questionnaire_spec.rb

**Checkpoint**: User Story 1 complete. Developers can access fields and create submissions using lowercase IDs. ✅

---

## Phase 4: User Story 2 - XBRL Output Preserves Original Casing (Priority: P1)

**Goal**: XBRL generation uses original element casing for regulatory compliance

**Independent Test**: Generate XBRL from submission with mixed-case field, verify element name matches original taxonomy

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T024 [P] [US2] Add test: XBRL element names use original casing (xbrl_id) in amsf_survey/spec/generator_spec.rb
- [x] T025 [P] [US2] Add test: mixed-case fields generate correct element names in amsf_survey/spec/generator_spec.rb

### Implementation for User Story 2

- [x] T026 [US2] Update Generator.build_fact to use field.xbrl_id for element names in amsf_survey/lib/amsf_survey/generator.rb
- [x] T027 [US2] Update remaining generator_spec.rb tests to use field IDs in amsf_survey/spec/generator_spec.rb

**Checkpoint**: User Story 2 complete. XBRL output uses original taxonomy casing. ✅

---

## Phase 5: User Story 3 - Progress Tracking for Survey Completion (Priority: P2)

**Goal**: CRM can show users their progress through visible fields

**Independent Test**: Create partially-filled submission, verify complete? and missing_fields work correctly

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T028 [P] [US3] Add test: complete? returns false when visible fields are unfilled in amsf_survey/spec/submission_spec.rb
- [x] T029 [P] [US3] Add test: missing_fields returns list of unfilled visible field IDs in amsf_survey/spec/submission_spec.rb
- [x] T030 [P] [US3] Add test: hidden fields (gate=false) not counted in missing_fields in amsf_survey/spec/submission_spec.rb

### Implementation for User Story 3

- [x] T031 [US3] Update complete? to check all visible fields have values in amsf_survey/lib/amsf_survey/submission.rb
- [x] T032 [US3] Update missing_fields to return lowercase field IDs in amsf_survey/lib/amsf_survey/submission.rb
- [x] T033 [US3] Verify gate visibility logic works with lowercase IDs in amsf_survey/lib/amsf_survey/submission.rb

**Checkpoint**: All user stories complete. Progress tracking works with lowercase IDs. ✅

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and documentation updates

- [x] T034 [P] Update test fixtures to use field IDs instead of semantic names in amsf_survey/spec/fixtures/
- [x] T035 [P] Run full test suite and verify all tests pass in amsf_survey/
- [x] T036 [P] Update CLAUDE.md to remove references to semantic_mappings.yml
- [ ] T037 Amend constitution Principle IV in .specify/memory/constitution.md
- [ ] T038 Run quickstart.md validation examples manually

---

## Summary

**All core implementation complete!** 310 tests pass.

### Key Changes Made

1. **Removed files:**
   - `validator.rb`, `validation_error.rb`, `validation_result.rb` (and specs)
   - `semantic_mappings.yml` (test fixture and real_estate)
   - `i18n_spec.rb` (tested removed Validator)

2. **Updated Field class:**
   - `id` now returns lowercase symbol
   - `xbrl_id` returns original casing for XBRL generation
   - Removed `name`, `source_type`, and related predicates

3. **Updated Loader:**
   - No longer loads `semantic_mappings.yml`
   - Normalizes `depends_on` keys to lowercase

4. **Updated Questionnaire:**
   - `field()` normalizes input to lowercase
   - Removed `computed_fields`, `prefillable_fields`, `entry_only_fields`

5. **Updated Submission:**
   - `[]` and `[]=` normalize field IDs to lowercase
   - `missing_fields` returns lowercase IDs

6. **Updated Generator:**
   - Uses `field.xbrl_id` for XBRL element names

### Remaining Tasks

- T037: Update constitution (if desired)
- T038: Manual validation of quickstart examples
