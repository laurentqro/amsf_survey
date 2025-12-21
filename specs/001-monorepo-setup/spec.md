# Feature Specification: Monorepo Structure Setup

**Feature Branch**: `001-monorepo-setup`
**Created**: 2025-12-21
**Status**: Draft
**Input**: Set up monorepo structure for amsf_survey core gem and real_estate plugin

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developer Installs Core Gem (Priority: P1)

A Ruby developer adds the `amsf_survey` gem to their application's Gemfile and runs bundle install. The gem installs successfully with all dependencies resolved.

**Why this priority**: Without a properly structured and installable gem, no other functionality can be built or used.

**Independent Test**: Run `gem build amsf_survey.gemspec` and verify it produces a valid `.gem` file that can be installed locally.

**Acceptance Scenarios**:

1. **Given** a Ruby project with a Gemfile, **When** the developer adds `gem 'amsf_survey'` and runs `bundle install`, **Then** the gem installs without errors
2. **Given** the core gem is installed, **When** the developer runs `require 'amsf_survey'`, **Then** the library loads without errors
3. **Given** the core gem is loaded, **When** the developer calls `AmsfSurvey.registered_industries`, **Then** an empty array is returned (no plugins loaded)

---

### User Story 2 - Developer Installs Industry Plugin (Priority: P2)

A developer working on a real estate compliance application adds the `amsf_survey-real_estate` plugin gem. The plugin automatically registers itself with the core gem.

**Why this priority**: Plugins extend the core gem with industry-specific taxonomies, enabling actual survey functionality.

**Independent Test**: Install both gems and verify `AmsfSurvey.registered_industries` returns `[:real_estate]`.

**Acceptance Scenarios**:

1. **Given** the core gem is installed, **When** the developer adds `gem 'amsf_survey-real_estate'` and bundles, **Then** both gems install without errors
2. **Given** both gems are loaded, **When** the developer calls `AmsfSurvey.registered_industries`, **Then** `:real_estate` is included in the returned array
3. **Given** the plugin is loaded, **When** the developer calls `AmsfSurvey.registered?(:real_estate)`, **Then** `true` is returned

---

### User Story 3 - Developer Runs Tests (Priority: P3)

A contributor to the project runs the test suite to verify their changes. All tests pass and coverage reports are generated.

**Why this priority**: A working test infrastructure enables TDD and validates all subsequent development.

**Independent Test**: Run `bundle exec rspec` in both gem directories and verify tests execute (even if just placeholder specs).

**Acceptance Scenarios**:

1. **Given** the developer is in the `amsf_survey/` directory, **When** they run `bundle exec rspec`, **Then** the test suite executes without configuration errors
2. **Given** the developer is in the `amsf_survey-real_estate/` directory, **When** they run `bundle exec rspec`, **Then** the test suite executes without configuration errors
3. **Given** tests run successfully, **When** the developer checks the output, **Then** a coverage percentage is displayed

---

### Edge Cases

- What happens when the plugin is loaded without the core gem? The plugin's require statement must explicitly require the core gem first.
- What happens when an unsupported Ruby version is used? The gemspec must specify minimum Ruby version (3.2+) and provide a clear error message.
- What happens when the taxonomy files are missing from the plugin? The plugin must validate taxonomy path existence at registration time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The monorepo MUST contain two separate gem directories: `amsf_survey/` (core) and `amsf_survey-real_estate/` (plugin)
- **FR-002**: Each gem MUST have its own gemspec, Gemfile, and README
- **FR-003**: The core gem MUST define the `AmsfSurvey` module as the public namespace
- **FR-004**: The core gem MUST provide a `register_plugin` method for industry plugins to register themselves
- **FR-005**: The core gem MUST provide `registered_industries`, `registered?`, and `supported_years` query methods
- **FR-006**: The plugin gem MUST require the core gem as a runtime dependency
- **FR-007**: The plugin gem MUST auto-register itself when required
- **FR-008**: Both gems MUST be configured for RSpec testing with SimpleCov for coverage
- **FR-009**: The core gem gemspec MUST specify Ruby 3.2+ as minimum version
- **FR-010**: The plugin gem MUST include taxonomy files in its gem package (via gemspec files directive)

### Key Entities

- **Registry**: Central registry in the core gem that tracks registered industry plugins and their taxonomy paths
- **Plugin**: An industry-specific gem that contains taxonomy files and registers with the core on load

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Both gems can be built successfully using `gem build`
- **SC-002**: The core gem loads in under 100ms on standard hardware
- **SC-003**: Running `bundle exec rspec` in each gem directory completes without errors
- **SC-004**: The plugin gem successfully registers with the core gem when both are required
- **SC-005**: 100% of public API methods have corresponding test coverage (even if placeholder)

## Assumptions

- Ruby 3.2+ is the minimum supported version (per constitution)
- RSpec is the testing framework (per design document)
- SimpleCov will be used for coverage reporting
- Nokogiri will be added as a dependency later (not in this initial setup)
- ActiveModel will be added as a dependency later (not in this initial setup)
- The taxonomy files currently in `docs/real_estate_taxonomy/` will be moved to the plugin gem structure
