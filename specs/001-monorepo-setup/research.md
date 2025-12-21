# Research: Monorepo Structure Setup

**Date**: 2025-12-21
**Feature**: 001-monorepo-setup

## Research Summary

This phase establishes foundational gem structure. All technical decisions are straightforward based on constitution requirements and Ruby gem conventions.

## Decision Log

### D1: Gemspec Structure

**Decision**: Use standard gemspec format with `spec.files = Dir["lib/**/*"]` pattern

**Rationale**:
- Industry-standard approach for Ruby gems
- Automatically includes all library files
- SimpleCov and RSpec as development dependencies only

**Alternatives considered**:
- Git-based file list (`git ls-files`) - rejected due to requiring git in build environment
- Explicit file list - rejected due to maintenance burden

### D2: Plugin Registration Pattern

**Decision**: Plugins call `AmsfSurvey.register_plugin` in their main require file

**Rationale**:
- Simple, explicit registration
- No magic or autoloading complexity
- Plugin controls when registration happens
- Follows Ruby convention (e.g., how Rails engines register)

**Alternatives considered**:
- Auto-discovery via gem naming convention - rejected as magic/complex
- Configuration file - rejected as over-engineering for this use case

### D3: Registry Implementation

**Decision**: Simple hash-based registry in the core gem

```ruby
module AmsfSurvey
  class << self
    def registered_industries
      @registry.keys
    end

    def registered?(industry)
      @registry.key?(industry)
    end

    def register_plugin(industry:, taxonomy_path:)
      @registry[industry] = { taxonomy_path: taxonomy_path }
    end
  end
end
```

**Rationale**:
- Minimal implementation per YAGNI principle
- No external dependencies
- Easy to extend later when taxonomy loading is added

**Alternatives considered**:
- Registry class with validation - deferred to when taxonomy loading is implemented
- Thread-safe concurrent hash - not needed for gem initialization

### D4: Test Infrastructure

**Decision**: RSpec 3.x with SimpleCov, configured in each gem independently

**Rationale**:
- Per constitution requirement for 100% coverage
- Independent test suites allow focused testing
- SimpleCov generates coverage reports automatically

**Configuration**:
```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'amsf_survey'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
end
```

### D5: Ruby Version Requirement

**Decision**: Ruby 3.2+ as minimum version

**Rationale**:
- Per constitution Technical Constraints
- 3.2 is stable and widely available
- Enables modern Ruby features (pattern matching, etc.)

### D6: Taxonomy File Location

**Decision**: Plugin gems store taxonomies in `taxonomies/{year}/` directory

**Rationale**:
- Clear separation from library code
- Year-based organization supports multi-year (future)
- Included in gem package via gemspec files directive

## No NEEDS CLARIFICATION Items

All technical decisions resolved based on constitution and Ruby conventions.
