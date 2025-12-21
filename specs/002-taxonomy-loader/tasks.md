# Tasks: Taxonomy Loader

**Input**: Design documents from `/specs/002-taxonomy-loader/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: TDD required per constitution (V. Test-First Development). Tests written before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

```text
amsf_survey/lib/amsf_survey/           # Source code
amsf_survey/spec/                       # Tests
amsf_survey/spec/fixtures/taxonomies/   # Test fixtures
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependency setup

- [ ] T001 Add Nokogiri dependency to amsf_survey/amsf_survey.gemspec
- [ ] T002 Run bundle install in amsf_survey/ directory
- [ ] T003 Create taxonomy/ directory at amsf_survey/lib/amsf_survey/taxonomy/
- [ ] T004 Create spec/amsf_survey/taxonomy/ directory for parser specs
- [ ] T005 Add custom exception classes to amsf_survey/lib/amsf_survey/errors.rb

---

## Phase 2: Foundational (Test Fixtures)

**Purpose**: Create synthetic test fixtures that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until fixtures are complete

- [ ] T006 Create test fixture directory at amsf_survey/spec/fixtures/taxonomies/test_industry/2025/
- [ ] T007 [P] Create test_survey.xsd fixture with 5 fields (integer, boolean, string, monetary, enum types)
- [ ] T008 [P] Create test_survey_lab.xml fixture with standard and verbose labels for each field
- [ ] T009 [P] Create test_survey_pre.xml fixture with 2 sections and field ordering
- [ ] T010 [P] Create test_survey.xule fixture with 2 gate dependency rules
- [ ] T011 [P] Create semantic_mappings.yml fixture mapping 3 of 5 fields (leaving 2 unmapped)

**Checkpoint**: Test fixtures ready - parser development can begin

---

## Phase 3: User Story 1 - Access Survey Questionnaire Structure (Priority: P1) 🎯 MVP

**Goal**: Developer can call `AmsfSurvey.questionnaire(industry:, year:)` and receive a complete Questionnaire object with sections and fields

**Independent Test**: Call questionnaire() with test_industry/2025 and verify sections and fields are populated

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T012 [P] [US1] Write Field class spec in amsf_survey/spec/amsf_survey/field_spec.rb
- [ ] T013 [P] [US1] Write Section class spec in amsf_survey/spec/amsf_survey/section_spec.rb
- [ ] T014 [P] [US1] Write Questionnaire class spec in amsf_survey/spec/amsf_survey/questionnaire_spec.rb
- [ ] T015 [P] [US1] Write SchemaParser spec in amsf_survey/spec/amsf_survey/taxonomy/schema_parser_spec.rb
- [ ] T016 [P] [US1] Write LabelParser spec in amsf_survey/spec/amsf_survey/taxonomy/label_parser_spec.rb
- [ ] T017 [P] [US1] Write PresentationParser spec in amsf_survey/spec/amsf_survey/taxonomy/presentation_parser_spec.rb
- [ ] T018 [P] [US1] Write Loader spec in amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb
- [ ] T019 [US1] Write caching test in registry_spec.rb for questionnaire() method

### Implementation for User Story 1

- [ ] T020 [P] [US1] Implement Field class in amsf_survey/lib/amsf_survey/field.rb
- [ ] T021 [P] [US1] Implement Section class in amsf_survey/lib/amsf_survey/section.rb
- [ ] T022 [US1] Implement Questionnaire class in amsf_survey/lib/amsf_survey/questionnaire.rb
- [ ] T023 [P] [US1] Implement SchemaParser in amsf_survey/lib/amsf_survey/taxonomy/schema_parser.rb
- [ ] T024 [P] [US1] Implement LabelParser in amsf_survey/lib/amsf_survey/taxonomy/label_parser.rb
- [ ] T025 [P] [US1] Implement PresentationParser in amsf_survey/lib/amsf_survey/taxonomy/presentation_parser.rb
- [ ] T026 [US1] Implement Loader in amsf_survey/lib/amsf_survey/taxonomy/loader.rb
- [ ] T027 [US1] Add questionnaire() method with caching to amsf_survey/lib/amsf_survey/registry.rb
- [ ] T028 [US1] Update amsf_survey/lib/amsf_survey.rb to require all new files
- [ ] T029 [US1] Run full test suite and verify 100% coverage for US1 components

**Checkpoint**: User Story 1 complete - questionnaire loading and caching works

---

## Phase 4: User Story 2 - Query Field Metadata (Priority: P1)

**Goal**: Developer can look up fields by semantic name or XBRL code and access all metadata

**Independent Test**: Load questionnaire, call field(:semantic_name), verify all attributes populated

### Tests for User Story 2

- [ ] T030 [P] [US2] Add field lookup specs to amsf_survey/spec/amsf_survey/questionnaire_spec.rb
- [ ] T031 [P] [US2] Add field attribute accessor specs to amsf_survey/spec/amsf_survey/field_spec.rb

### Implementation for User Story 2

- [ ] T032 [US2] Implement field(id) lookup in Questionnaire (by name and XBRL code)
- [ ] T033 [US2] Add type helper methods to Field (boolean?, integer?, monetary?, enum?)
- [ ] T034 [US2] Verify valid_values populated for enum/boolean fields
- [ ] T035 [US2] Run test suite and verify all US2 specs pass

**Checkpoint**: User Story 2 complete - field lookup works by name or code

---

## Phase 5: User Story 3 - Filter Fields by Source Type (Priority: P2)

**Goal**: Developer can filter fields by source_type (computed, prefillable, entry_only)

**Independent Test**: Call prefillable_fields, verify only fields with source_type: :prefillable returned

### Tests for User Story 3

- [ ] T036 [P] [US3] Add source type filter specs to amsf_survey/spec/amsf_survey/questionnaire_spec.rb
- [ ] T037 [P] [US3] Add source_type helper specs to amsf_survey/spec/amsf_survey/field_spec.rb

### Implementation for User Story 3

- [ ] T038 [US3] Implement computed_fields, prefillable_fields, entry_only_fields on Questionnaire
- [ ] T039 [US3] Add computed?, prefillable?, entry_only? helper methods to Field
- [ ] T040 [US3] Run test suite and verify all US3 specs pass

**Checkpoint**: User Story 3 complete - source type filtering works

---

## Phase 6: User Story 4 - Determine Field Visibility (Priority: P2)

**Goal**: Developer can check if a field is visible based on gate question answers

**Independent Test**: Call field.visible?(data) with different gate values, verify correct visibility

### Tests for User Story 4

- [ ] T041 [P] [US4] Write XuleParser spec in amsf_survey/spec/amsf_survey/taxonomy/xule_parser_spec.rb
- [ ] T042 [P] [US4] Add visible? specs to amsf_survey/spec/amsf_survey/field_spec.rb
- [ ] T043 [US4] Add gate_fields spec to amsf_survey/spec/amsf_survey/questionnaire_spec.rb

### Implementation for User Story 4

- [ ] T044 [US4] Implement XuleParser in amsf_survey/lib/amsf_survey/taxonomy/xule_parser.rb
- [ ] T045 [US4] Update Loader to call XuleParser and set depends_on/gate on fields
- [ ] T046 [US4] Implement visible?(data) on Field class
- [ ] T047 [US4] Implement gate_fields on Questionnaire
- [ ] T048 [US4] Add required? method to Field (true if has dependencies or not computed)
- [ ] T049 [US4] Run test suite and verify all US4 specs pass

**Checkpoint**: User Story 4 complete - gate visibility logic works

---

## Phase 7: User Story 5 - Navigate Sections (Priority: P3)

**Goal**: Developer can iterate sections in presentation order with fields grouped

**Independent Test**: Iterate questionnaire.sections, verify order and field grouping

### Tests for User Story 5

- [ ] T050 [P] [US5] Add section ordering specs to amsf_survey/spec/amsf_survey/questionnaire_spec.rb
- [ ] T051 [P] [US5] Add section visibility specs to amsf_survey/spec/amsf_survey/section_spec.rb

### Implementation for User Story 5

- [ ] T052 [US5] Ensure sections are returned in presentation order from Questionnaire
- [ ] T053 [US5] Ensure fields within section are in display order
- [ ] T054 [US5] Implement visible?(data) on Section (true if any field visible)
- [ ] T055 [US5] Add field_count and empty? helpers to Section
- [ ] T056 [US5] Run test suite and verify all US5 specs pass

**Checkpoint**: User Story 5 complete - section navigation works

---

## Phase 8: Edge Cases & Error Handling

**Purpose**: Handle error conditions and edge cases from spec

### Tests for Edge Cases

- [ ] T057 [P] Add missing file error specs to amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb
- [ ] T058 [P] Add malformed XML error specs to amsf_survey/spec/amsf_survey/taxonomy/schema_parser_spec.rb
- [ ] T059 [P] Add unmapped field default behavior specs to amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb
- [ ] T060 [P] Add nested gate dependency specs to amsf_survey/spec/amsf_survey/field_spec.rb

### Implementation for Edge Cases

- [ ] T061 Implement MissingTaxonomyFileError with file path in message
- [ ] T062 Implement MalformedTaxonomyError with parse details
- [ ] T063 Implement MissingSemanticMappingError
- [ ] T064 Handle fields not in mappings (use XBRL code as name, default source_type)
- [ ] T065 Handle nested gate dependencies in visible? evaluation
- [ ] T066 Handle fields with no label (use XBRL code as fallback)
- [ ] T067 Run full test suite and verify 100% coverage

**Checkpoint**: All edge cases handled

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and real taxonomy integration

- [ ] T068 Create semantic_mappings.yml for real_estate plugin at amsf_survey-real_estate/taxonomies/2025/semantic_mappings.yml
- [ ] T069 [P] Add integration test loading real_estate taxonomy in amsf_survey/spec/integration/
- [ ] T070 Verify performance: questionnaire load < 2 seconds
- [ ] T071 Verify caching: second load < 10 milliseconds
- [ ] T072 Run full test suite across both gems
- [ ] T073 Update CLAUDE.md with new classes and patterns

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (Fixtures)**: Depends on Phase 1 - BLOCKS all user stories
- **Phases 3-7 (User Stories)**: All depend on Phase 2 completion
- **Phase 8 (Edge Cases)**: Depends on Phases 3-7
- **Phase 9 (Polish)**: Depends on Phase 8

### User Story Dependencies

- **US1 (P1)**: Core loading - no dependencies on other stories
- **US2 (P1)**: Field metadata - builds on US1 models but independently testable
- **US3 (P2)**: Source type filtering - uses US1 models but independently testable
- **US4 (P2)**: Gate visibility - adds XuleParser, independently testable
- **US5 (P3)**: Section navigation - uses existing models, independently testable

### Within Each User Story

1. Tests MUST be written and FAIL before implementation
2. Models/parsers can be developed in parallel (marked [P])
3. Loader depends on all parsers
4. Integration depends on models + loader
5. Run tests after each task group

### Parallel Opportunities

Within each phase, tasks marked [P] can run in parallel:
- T007-T011: All fixture files in parallel
- T012-T018: All spec files in parallel
- T020-T021, T023-T025: Models and parsers in parallel

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all US1 test files together (TDD - write tests first):
Task: "Write Field class spec in amsf_survey/spec/amsf_survey/field_spec.rb"
Task: "Write Section class spec in amsf_survey/spec/amsf_survey/section_spec.rb"
Task: "Write Questionnaire class spec in amsf_survey/spec/amsf_survey/questionnaire_spec.rb"
Task: "Write SchemaParser spec in amsf_survey/spec/amsf_survey/taxonomy/schema_parser_spec.rb"
Task: "Write LabelParser spec in amsf_survey/spec/amsf_survey/taxonomy/label_parser_spec.rb"
Task: "Write PresentationParser spec in amsf_survey/spec/amsf_survey/taxonomy/presentation_parser_spec.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (Nokogiri, directories)
2. Complete Phase 2: Fixtures (test taxonomy files)
3. Complete Phase 3: User Story 1 (basic loading)
4. **STOP and VALIDATE**: `bundle exec rspec` passes, questionnaire loads
5. Commit and push - MVP functional

### Incremental Delivery

1. Setup + Fixtures → Ready for development
2. User Story 1 → Can load questionnaires (MVP!)
3. User Story 2 → Can look up field metadata
4. User Story 3 → Can filter by source type
5. User Story 4 → Gate visibility works
6. User Story 5 → Section navigation works
7. Edge Cases → Robust error handling
8. Polish → Real taxonomy integration

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- TDD required: tests must fail before implementation
- 100% coverage required per constitution
- Commit after each story completion
- Stop at any checkpoint to validate independently
