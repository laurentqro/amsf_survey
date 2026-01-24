# Implementation Plan: Remove Semantic Name Indirection

**Branch**: `005-remove-semantic-indirection` | **Date**: 2025-01-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-remove-semantic-indirection/spec.md`

## Summary

Remove the semantic name indirection layer that maps XBRL element IDs (like `a1101`) to semantic Ruby names (like `total_clients`). Consumers will use lowercase XBRL IDs directly in the API while XBRL generation preserves original casing. This eliminates `semantic_mappings.yml` maintenance and simplifies taxonomy updates.

## Technical Context

**Language/Version**: Ruby 3.2+
**Primary Dependencies**: Nokogiri ~> 1.15 (XML parsing/generation)
**Storage**: N/A (file-based taxonomy loading)
**Testing**: RSpec with 100% coverage requirement
**Target Platform**: Ruby gem (cross-platform)
**Project Type**: Monorepo with core gem and industry plugin gems
**Performance Goals**: O(1) field lookup via hash indexing
**Constraints**: XBRL output must match taxonomy element casing exactly
**Scale/Scope**: 323 fields in real_estate taxonomy, ~10 core classes affected

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Consumer-Agnostic Core | PASS | No consumer knowledge introduced |
| II. Industry-Agnostic Architecture | PASS | Core remains industry-agnostic |
| III. Taxonomy as Source of Truth | PASS | Removes semantic_mappings.yml, increases taxonomy authority |
| IV. Semantic Abstraction | **VIOLATION** | Feature removes semantic names; consumers will use XBRL codes |
| V. Test-First Development | PASS | Will follow TDD |
| VI. Simplicity and YAGNI | PASS | Reduces complexity by removing indirection layer |

### Violation Justification (Principle IV)

The constitution states: "Consumers MUST have no notion of XBRL internals."

**Why this violation is necessary:**
1. The semantic mapping layer adds maintenance burden without reducing coupling
2. When AMSF updates the questionnaire, we currently must update both taxonomy files AND semantic_mappings.yml
3. The consuming CRM has found that using XBRL IDs directly is simpler than maintaining the mapping
4. XBRL codes are stable identifiers that rarely change between years

**Constitutional Amendment Proposed:**
Replace Principle IV with: "Consumers use lowercase field IDs (derived from XBRL element names) through Ruby-friendly accessors. XBRL generation is an internal detail."

## Project Structure

### Documentation (this feature)

```text
specs/005-remove-semantic-indirection/
├── plan.md              # This file
├── research.md          # Phase 0 output (N/A - no unknowns)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
amsf_survey/                          # Core gem
├── lib/
│   └── amsf_survey/
│       ├── field.rb                  # MODIFY: Add xbrl_id, remove name/source_type
│       ├── questionnaire.rb          # MODIFY: Remove dual indexing, normalize lookups
│       ├── submission.rb             # MODIFY: Normalize keys to lowercase
│       ├── generator.rb              # MODIFY: Use xbrl_id for element names
│       ├── validator.rb              # DELETE: Remove entire module
│       └── taxonomy/
│           └── loader.rb             # MODIFY: Stop loading semantic_mappings.yml
└── spec/
    ├── field_spec.rb                 # MODIFY: Update for new API
    ├── questionnaire_spec.rb         # MODIFY: Update lookups
    ├── submission_spec.rb            # MODIFY: Use field IDs
    ├── generator_spec.rb             # MODIFY: Verify original casing
    ├── validator_spec.rb             # DELETE: Remove tests
    └── fixtures/
        └── taxonomies/
            └── test_industry/
                └── 2025/
                    └── semantic_mappings.yml  # DELETE

amsf_survey-real_estate/              # Industry plugin
└── taxonomies/
    └── 2025/
        └── semantic_mappings.yml     # DELETE
```

**Structure Decision**: Existing monorepo structure. Changes are subtractive (removing files and code) plus modifications to existing classes.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle IV (Semantic Abstraction) | Semantic mapping adds maintenance without reducing coupling | Keeping the mapping means updating TWO files when taxonomy changes; XBRL codes are stable identifiers |

## Phase 0: Research

No unknowns to research. The codebase is well-understood from the brainstorming session, and all technical decisions have been made:

- **Case handling**: Lowercase at accessor, preserve original for XBRL
- **Semantic mappings**: Remove entirely (no need to preserve source_type)
- **Validation**: Remove Ruby-native validation (Arelle is authoritative)
- **Completeness tracking**: Keep `complete?` and `missing_fields` for CRM progress indicators
- **Gate/visibility logic**: Keep as-is for progress tracking and XBRL output

## Phase 1: Design

### Data Model Changes

See [data-model.md](./data-model.md) for detailed entity changes.

### API Contract Changes

No external API contracts (this is a Ruby gem). Internal API changes documented in spec.md and quickstart.md.

## Files to Create/Modify/Delete

### DELETE
- `amsf_survey/lib/amsf_survey/validator.rb`
- `amsf_survey/spec/validator_spec.rb`
- `amsf_survey/spec/fixtures/taxonomies/test_industry/2025/semantic_mappings.yml`
- `amsf_survey-real_estate/taxonomies/2025/semantic_mappings.yml`

### MODIFY
- `amsf_survey/lib/amsf_survey/field.rb` - Add xbrl_id, remove name/source_type/predicates
- `amsf_survey/lib/amsf_survey/questionnaire.rb` - Remove dual indexing, add lowercase normalization
- `amsf_survey/lib/amsf_survey/submission.rb` - Normalize keys to lowercase
- `amsf_survey/lib/amsf_survey/generator.rb` - Use xbrl_id for element names
- `amsf_survey/lib/amsf_survey/taxonomy/loader.rb` - Stop loading semantic_mappings.yml
- `amsf_survey/lib/amsf_survey.rb` - Remove validate method
- All spec files - Update to use field IDs instead of semantic names

## Next Steps

Run `/speckit.tasks` to generate the implementation task list.
