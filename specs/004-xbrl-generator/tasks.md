# Tasks: XBRL Generator

**Input**: Design documents from `/specs/004-xbrl-generator/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Following constitution requirement for test-first development with 100% coverage.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Ruby gem**: `amsf_survey/lib/amsf_survey/` for source, `amsf_survey/spec/` for tests
- Following existing monorepo structure per plan.md

---

## Phase 1: Setup

**Purpose**: Foundational infrastructure required before Generator can be implemented

- [ ] T001 [P] Add `taxonomy_namespace` attribute to Questionnaire in `amsf_survey/lib/amsf_survey/questionnaire.rb`
- [ ] T002 [P] Enhance SchemaParser to extract `targetNamespace` from XSD in `amsf_survey/lib/amsf_survey/taxonomy/schema_parser.rb`
- [ ] T003 Update Loader to pass `taxonomy_namespace` to Questionnaire in `amsf_survey/lib/amsf_survey/taxonomy/loader.rb`
- [ ] T004 [P] Add test fixture XSD with `targetNamespace` in `amsf_survey/spec/fixtures/taxonomies/test_industry/2025/test_survey.xsd`
- [ ] T005 [P] Add tests for taxonomy_namespace extraction in `amsf_survey/spec/amsf_survey/taxonomy/schema_parser_spec.rb`
- [ ] T006 [P] Add tests for Questionnaire taxonomy_namespace in `amsf_survey/spec/amsf_survey/questionnaire_spec.rb`

**Checkpoint**: Questionnaire now exposes `taxonomy_namespace` from XSD - Generator can be implemented

---

## Phase 2: User Story 1 - Generate XBRL from Complete Submission (Priority: P1) 🎯 MVP

**Goal**: Generate valid XBRL instance XML with namespaces, context, and facts from a Submission

**Independent Test**: Create a Submission with sample data, generate XBRL, verify well-formed XML with correct structure

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T007 [P] [US1] Create Generator spec file with basic structure in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T008 [P] [US1] Test: generates well-formed XML with declaration and encoding in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T009 [P] [US1] Test: includes required XBRL namespaces (xbrli, link, xlink, strix) in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T010 [P] [US1] Test: generates context with entity identifier and period instant in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T011 [P] [US1] Test: generates facts with XBRL code element names and contextRef in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T012 [P] [US1] Test: integer fields have decimals="0" attribute in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T013 [P] [US1] Test: monetary fields have decimals="2" attribute in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T014 [P] [US1] Test: boolean true outputs "Oui", false outputs "Non" in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T015 [P] [US1] Test: enum fields output selected value as content in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T016 [P] [US1] Test: string fields output text content without decimals in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T017 [P] [US1] Test: escapes special XML characters in values in `amsf_survey/spec/amsf_survey/generator_spec.rb`

### Implementation for User Story 1

- [ ] T018 [US1] Create Generator class skeleton with initialize(submission, options) in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T019 [US1] Implement namespace constants (XBRLI_NS, LINK_NS, XLINK_NS) in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T020 [US1] Implement context_id generation method in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T021 [US1] Implement build_document method with Nokogiri Builder in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T022 [US1] Implement build_namespaces method in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T023 [US1] Implement build_context method (entity + period) in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T024 [US1] Implement build_facts method (iterate visible fields) in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T025 [US1] Implement format_value method (boolean→French, numeric→string) in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T026 [US1] Implement decimals_for method (type→decimals attribute) in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T027 [US1] Implement generate public method (orchestrates building) in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T028 [US1] Add require for generator.rb in `amsf_survey/lib/amsf_survey.rb`
- [ ] T029 [US1] Add to_xbrl method to AmsfSurvey module in `amsf_survey/lib/amsf_survey/registry.rb`

**Checkpoint**: User Story 1 complete - can generate basic XBRL from any complete submission

---

## Phase 3: User Story 2 - Control Output Formatting (Priority: P2)

**Goal**: Support pretty printing option for human-readable vs compact XML

**Independent Test**: Generate XBRL with pretty:true and pretty:false, compare formatting

### Tests for User Story 2

- [ ] T030 [P] [US2] Test: default (pretty:false) outputs minified XML in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T031 [P] [US2] Test: pretty:true outputs indented XML in `amsf_survey/spec/amsf_survey/generator_spec.rb`

### Implementation for User Story 2

- [ ] T032 [US2] Add pretty option handling in Generator#initialize in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T033 [US2] Implement output formatting in Generator#generate based on pretty flag in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T034 [US2] Update AmsfSurvey.to_xbrl to pass pretty option in `amsf_survey/lib/amsf_survey/registry.rb`

**Checkpoint**: User Story 2 complete - can control output formatting

---

## Phase 4: User Story 3 - Handle Empty and Nil Fields (Priority: P2)

**Goal**: Support include_empty option for nil field handling

**Independent Test**: Generate XBRL with nil fields using both include_empty values, verify output

### Tests for User Story 3

- [ ] T035 [P] [US3] Test: include_empty:true (default) includes empty facts for nil values in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T036 [P] [US3] Test: include_empty:false omits facts for nil values in `amsf_survey/spec/amsf_survey/generator_spec.rb`

### Implementation for User Story 3

- [ ] T037 [US3] Add include_empty option handling in Generator#initialize in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T038 [US3] Update build_facts to skip nil values when include_empty:false in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T039 [US3] Update AmsfSurvey.to_xbrl to pass include_empty option in `amsf_survey/lib/amsf_survey/registry.rb`

**Checkpoint**: User Story 3 complete - can control empty field handling

---

## Phase 5: User Story 4 - Generate from Incomplete Submission (Priority: P3)

**Goal**: Generate XBRL for preview even with missing/invalid data

**Independent Test**: Generate XBRL from incomplete submission, verify valid XML structure

### Tests for User Story 4

- [ ] T040 [P] [US4] Test: generates XML when some fields are missing in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T041 [P] [US4] Test: hidden fields (gate-controlled) are excluded from output in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T042 [P] [US4] Test: generates valid context even with no field data in `amsf_survey/spec/amsf_survey/generator_spec.rb`

### Implementation for User Story 4

- [ ] T043 [US4] Ensure build_facts handles empty data hash gracefully in `amsf_survey/lib/amsf_survey/generator.rb`
- [ ] T044 [US4] Add visible field filtering using field.visible?(data) in build_facts in `amsf_survey/lib/amsf_survey/generator.rb`

**Checkpoint**: User Story 4 complete - can preview XBRL from incomplete submissions

---

## Phase 6: Edge Cases & Integration

**Purpose**: Handle edge cases and validate end-to-end

### Edge Case Tests

- [ ] T045 [P] Test: period date formatting (YYYY-MM-DD) in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T046 [P] Test: entity_id with special characters escaped in `amsf_survey/spec/amsf_survey/generator_spec.rb`
- [ ] T047 [P] Test: percentage fields have decimals="2" in `amsf_survey/spec/amsf_survey/generator_spec.rb`

### Integration Tests

- [ ] T048 Create integration test file in `amsf_survey/spec/integration/xbrl_generation_spec.rb`
- [ ] T049 [P] Integration test: generate XBRL from real_estate taxonomy submission in `amsf_survey/spec/integration/xbrl_generation_spec.rb`
- [ ] T050 [P] Integration test: verify output is parseable by Nokogiri in `amsf_survey/spec/integration/xbrl_generation_spec.rb`
- [ ] T051 Integration test: performance under 100ms for full questionnaire in `amsf_survey/spec/integration/xbrl_generation_spec.rb`

### Implementation Fixes

- [ ] T052 Add GenerationError class to errors.rb if needed in `amsf_survey/lib/amsf_survey/errors.rb`
- [ ] T053 Handle invalid period date format with clear error in `amsf_survey/lib/amsf_survey/generator.rb`

**Checkpoint**: All edge cases handled, integration verified

---

## Phase 7: Polish & Documentation

**Purpose**: Final quality improvements

- [ ] T054 [P] Run full test suite and verify 100% coverage for new code
- [ ] T055 [P] Update CLAUDE.md with Generator documentation
- [ ] T056 Validate quickstart.md examples work correctly
- [ ] T057 [P] Run RuboCop and fix any style issues

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - enhances existing infrastructure
- **User Story 1 (Phase 2)**: Depends on Setup - core generation
- **User Story 2 (Phase 3)**: Depends on US1 - adds formatting option
- **User Story 3 (Phase 4)**: Depends on US1 - adds empty handling option
- **User Story 4 (Phase 5)**: Depends on US1 - adds incomplete handling
- **Edge Cases (Phase 6)**: Depends on all user stories
- **Polish (Phase 7)**: Depends on all phases

### Within Each User Story

1. Tests written FIRST (all marked [P] can run in parallel)
2. Tests verified to FAIL
3. Implementation tasks in order (T0XX → T0XX+1)
4. Tests verified to PASS
5. Story checkpoint validated

### Parallel Opportunities

**Setup Phase (T001-T006):**
- T001, T002, T004, T005, T006 can run in parallel (different files)
- T003 depends on T001, T002

**User Story 1 Tests (T007-T017):**
- All tests can be written in parallel (same file but independent examples)

**User Story 1 Implementation (T018-T029):**
- T018-T026 are sequential (building on each other)
- T028, T029 can run in parallel after T027

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all US1 tests together (same file):
# T007-T017 all write to generator_spec.rb
# They define independent examples that can be written in any order
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T006) → taxonomy_namespace available
2. Complete Phase 2: User Story 1 (T007-T029) → basic XBRL generation works
3. **STOP and VALIDATE**: Generate XBRL, verify XML structure
4. MVP ready for demo/testing

### Incremental Delivery

1. Setup → Foundation ready
2. Add US1 → Core XBRL generation (MVP!)
3. Add US2 → Pretty printing option
4. Add US3 → Empty field handling
5. Add US4 → Preview/incomplete support
6. Edge Cases + Polish → Production ready

### Suggested MVP Scope

**Tasks T001-T029** (Setup + User Story 1) deliver a working XBRL generator that:
- Generates valid XBRL 2.1 instance documents
- Includes proper namespaces, context, and facts
- Handles all field types (boolean, integer, monetary, string, enum)
- Can be tested and demonstrated immediately

---

## Notes

- [P] tasks = different files or independent test examples
- [Story] label maps task to specific user story
- Test-first per constitution - all tests must fail before implementation
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All tests in generator_spec.rb but organized by user story context blocks
