# Tasks: Monorepo Structure Setup

**Input**: Design documents from `/specs/001-monorepo-setup/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Included per constitution V (Test-First Development) and SC-005 (100% coverage requirement).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Core gem**: `amsf_survey/` directory
- **Plugin gem**: `amsf_survey-real_estate/` directory
- Tests in `spec/` within each gem directory

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure for both gems

- [X] T001 Create core gem directory structure: `amsf_survey/lib/amsf_survey/`, `amsf_survey/spec/amsf_survey/`
- [X] T002 [P] Create plugin gem directory structure: `amsf_survey-real_estate/lib/amsf_survey/`, `amsf_survey-real_estate/spec/amsf_survey/`, `amsf_survey-real_estate/taxonomies/2025/`
- [X] T003 [P] Move taxonomy files from `docs/real_estate_taxonomy/` to `amsf_survey-real_estate/taxonomies/2025/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core gem gemspec, Gemfile, and test infrastructure that MUST be complete before user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Create core gem gemspec in `amsf_survey/amsf_survey.gemspec` with Ruby 3.2+ requirement, RSpec/SimpleCov dev dependencies
- [X] T005 [P] Create core gem Gemfile in `amsf_survey/Gemfile` referencing gemspec
- [X] T006 [P] Create core gem Rakefile in `amsf_survey/Rakefile` with default spec task
- [X] T007 [P] Create core gem README in `amsf_survey/README.md` with basic usage
- [X] T008 Create core gem spec_helper in `amsf_survey/spec/spec_helper.rb` with SimpleCov configuration
- [X] T009 [P] Create plugin gem gemspec in `amsf_survey-real_estate/amsf_survey-real_estate.gemspec` with amsf_survey runtime dependency
- [X] T010 [P] Create plugin gem Gemfile in `amsf_survey-real_estate/Gemfile` referencing gemspec
- [X] T011 [P] Create plugin gem Rakefile in `amsf_survey-real_estate/Rakefile` with default spec task
- [X] T012 [P] Create plugin gem README in `amsf_survey-real_estate/README.md` with basic usage
- [X] T013 Create plugin gem spec_helper in `amsf_survey-real_estate/spec/spec_helper.rb` with SimpleCov configuration

**Checkpoint**: Foundation ready - both gems have gemspecs, Gemfiles, and test infrastructure

---

## Phase 3: User Story 1 - Developer Installs Core Gem (Priority: P1) 🎯 MVP

**Goal**: Core gem builds, installs, and loads with empty registry

**Independent Test**: Run `gem build amsf_survey.gemspec` and verify `.gem` file is created; `require 'amsf_survey'` loads without errors

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T014 [P] [US1] Write spec for AmsfSurvey module in `amsf_survey/spec/amsf_survey_spec.rb` testing version constant exists
- [X] T015 [P] [US1] Write spec for registry methods in `amsf_survey/spec/amsf_survey/registry_spec.rb` testing registered_industries returns empty array, registered? returns false for unknown

### Implementation for User Story 1

- [X] T016 [US1] Create version file in `amsf_survey/lib/amsf_survey/version.rb` with VERSION constant "0.1.0"
- [X] T017 [US1] Create registry module in `amsf_survey/lib/amsf_survey/registry.rb` with register_plugin, registered_industries, registered?, supported_years methods
- [X] T018 [US1] Create main entry point in `amsf_survey/lib/amsf_survey.rb` requiring version and registry, initializing empty registry hash
- [X] T019 [US1] Run `bundle install` in `amsf_survey/` and verify dependencies install
- [X] T020 [US1] Run `bundle exec rspec` in `amsf_survey/` and verify all tests pass with coverage
- [X] T021 [US1] Run `gem build amsf_survey.gemspec` in `amsf_survey/` and verify `.gem` file is created

**Checkpoint**: Core gem is buildable, installable, and returns empty registry. User Story 1 complete.

---

## Phase 4: User Story 2 - Developer Installs Industry Plugin (Priority: P2)

**Goal**: Plugin gem auto-registers with core gem when required

**Independent Test**: Require both gems and verify `AmsfSurvey.registered_industries` returns `[:real_estate]`

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T022 [P] [US2] Write spec for real_estate registration in `amsf_survey-real_estate/spec/amsf_survey/real_estate_spec.rb` testing plugin registers on require, registered? returns true, taxonomy_path is valid

### Implementation for User Story 2

- [X] T023 [US2] Create plugin entry point in `amsf_survey-real_estate/lib/amsf_survey/real_estate.rb` that requires core gem and calls register_plugin with industry: :real_estate and taxonomy_path
- [X] T024 [US2] Update plugin gemspec `amsf_survey-real_estate/amsf_survey-real_estate.gemspec` to include taxonomies directory in files
- [X] T025 [US2] Run `bundle install` in `amsf_survey-real_estate/` and verify dependencies install (including local core gem path)
- [X] T026 [US2] Run `bundle exec rspec` in `amsf_survey-real_estate/` and verify all tests pass with coverage
- [X] T027 [US2] Run `gem build amsf_survey-real_estate.gemspec` in `amsf_survey-real_estate/` and verify `.gem` file is created

**Checkpoint**: Plugin gem builds, installs, and auto-registers with core. User Story 2 complete.

---

## Phase 5: User Story 3 - Developer Runs Tests (Priority: P3)

**Goal**: Both gems have working test suites with coverage reporting

**Independent Test**: Run `bundle exec rspec` in both gem directories and see coverage percentages

### Tests for User Story 3

> Tests for this story are the test infrastructure itself - validated by running rspec

### Implementation for User Story 3

- [X] T028 [US3] Verify SimpleCov generates coverage report in `amsf_survey/coverage/` after running specs
- [X] T029 [US3] Verify SimpleCov generates coverage report in `amsf_survey-real_estate/coverage/` after running specs
- [X] T030 [US3] Verify coverage is 100% for all public API methods in both gems
- [X] T031 [US3] Add `.gitignore` entries for `coverage/` and `*.gem` in repository root

**Checkpoint**: Both gems have passing tests with 100% coverage. User Story 3 complete.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [X] T032 Run quickstart.md verification checklist from `specs/001-monorepo-setup/quickstart.md`
- [X] T033 [P] Verify edge case: plugin loading without core gem fails gracefully
- [X] T034 [P] Verify edge case: unsupported Ruby version shows clear error (test by checking gemspec)
- [X] T035 Verify both gems can be required together: `require 'amsf_survey'; require 'amsf_survey/real_estate'`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - Core gem implementation
- **User Story 2 (Phase 4)**: Depends on User Story 1 - Plugin needs working core gem
- **User Story 3 (Phase 5)**: Depends on User Stories 1 & 2 - Tests validate both gems
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Depends on User Story 1 - Plugin registers with core gem registry
- **User Story 3 (P3)**: Depends on User Stories 1 & 2 - Tests verify both gems

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Version/module files before entry point
- Entry point requires all modules
- Bundle install before running tests
- Tests pass before building gem

### Parallel Opportunities

- T001, T002, T003 can run in parallel (different directories)
- T004 must complete first, then T005-T013 can run in parallel
- T014, T015 can run in parallel (different spec files)
- T022 is independent (different gem)
- T028, T029 can run in parallel (different gems)
- T033, T034 can run in parallel (independent edge cases)

---

## Parallel Example: Phase 2 (Foundational)

```bash
# After T004 completes, launch these in parallel:
Task: "Create core gem Gemfile in amsf_survey/Gemfile"
Task: "Create core gem Rakefile in amsf_survey/Rakefile"
Task: "Create core gem README in amsf_survey/README.md"
Task: "Create plugin gem gemspec in amsf_survey-real_estate/amsf_survey-real_estate.gemspec"
Task: "Create plugin gem Gemfile in amsf_survey-real_estate/Gemfile"
Task: "Create plugin gem Rakefile in amsf_survey-real_estate/Rakefile"
Task: "Create plugin gem README in amsf_survey-real_estate/README.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T013)
3. Complete Phase 3: User Story 1 (T014-T021)
4. **STOP and VALIDATE**: Core gem builds and loads
5. Deploy/demo if ready - core gem is usable

### Incremental Delivery

1. Setup + Foundational → Both gem structures ready
2. User Story 1 → Core gem works → MVP!
3. User Story 2 → Plugin registers → Usable for real estate surveys
4. User Story 3 → Full test coverage → Production ready
5. Polish → All edge cases handled

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- TDD required per constitution V
