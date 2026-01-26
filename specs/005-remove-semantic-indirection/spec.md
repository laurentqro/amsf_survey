# Feature Specification: Remove Semantic Name Indirection

**Feature Branch**: `005-remove-semantic-indirection`
**Created**: 2025-01-24
**Status**: Draft
**Input**: User description: "Remove semantic name indirection from amsf_survey gem - use XBRL element IDs directly instead of semantic field names"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - CRM Developer Uses Field IDs Directly (Priority: P1)

A CRM developer building an AMSF survey submission interface wants to reference fields using their XBRL element IDs (like `a1101`, `aactive`) instead of semantic names (like `total_clients`, `has_activity`). This removes the need to maintain a mapping layer and simplifies updates when AMSF releases new questionnaire versions.

**Why this priority**: This is the core value proposition. Direct ID usage eliminates the maintenance burden of semantic_mappings.yml and reduces friction when updating to new AMSF taxonomy versions.

**Independent Test**: Can be fully tested by creating a submission with field IDs and verifying field access and XBRL generation work correctly.

**Acceptance Scenarios**:

1. **Given** a questionnaire is loaded, **When** I access a field using its lowercase ID (e.g., `:a1101`), **Then** I receive the correct Field object
2. **Given** I create a submission with data keyed by lowercase field IDs, **When** I access the data, **Then** values are correctly stored and retrievable
3. **Given** a field has mixed-case XBRL ID (e.g., `aACTIVE`), **When** I access it via lowercase (`:aactive`), **Then** it resolves correctly

---

### User Story 2 - XBRL Output Preserves Original Casing (Priority: P1)

A CRM developer generating XBRL for submission to the AMSF Strix portal needs the output XML to use the exact element names from the original XBRL taxonomy (e.g., `<strix:aACTIVE>` not `<strix:aactive>`), even though the Ruby API uses lowercase.

**Why this priority**: AMSF may reject submissions with incorrect element casing. This is critical for regulatory compliance.

**Independent Test**: Can be tested by generating XBRL from a submission and verifying element names match the original taxonomy casing.

**Acceptance Scenarios**:

1. **Given** a submission with field `:aactive` set to `true`, **When** I generate XBRL, **Then** the output contains `<strix:aACTIVE>Oui</strix:aACTIVE>` (original casing)
2. **Given** a field with lowercase original ID (e.g., `a1101`), **When** I generate XBRL, **Then** the output contains `<strix:a1101>` (unchanged)

---

### User Story 3 - Progress Tracking for Survey Completion (Priority: P2)

A CRM developer wants to show users their progress through the survey form by indicating how many required visible fields have been filled.

**Why this priority**: Provides UX value for form completion but is not essential for submission generation.

**Independent Test**: Can be tested by creating a partially-filled submission and verifying `complete?` and `missing_fields` return accurate counts.

**Acceptance Scenarios**:

1. **Given** a submission with 10 visible required fields and 7 filled, **When** I check `submission.complete?`, **Then** it returns `false`
2. **Given** a submission with 10 visible required fields and 7 filled, **When** I check `submission.missing_fields`, **Then** it returns 3 field IDs
3. **Given** a gate field is set to hide dependent fields, **When** I check completion, **Then** hidden fields are not counted as missing

---

### Edge Cases

- What happens when a developer passes a mixed-case ID (e.g., `:aACTIVE`) to the API? The system normalizes to lowercase.
- What happens when a field ID doesn't exist in the questionnaire? The system raises an error (existing behavior preserved).
- What happens when the `semantic_mappings.yml` file is present in an updated taxonomy? It is ignored (no longer loaded).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Field class MUST expose `id` as a lowercase symbol (e.g., `:a1101`, `:aactive`)
- **FR-002**: Field class MUST expose `xbrl_id` containing the original casing from the taxonomy (e.g., `:aACTIVE`)
- **FR-003**: Questionnaire field lookup MUST normalize input to lowercase before matching
- **FR-004**: Submission data hash MUST be keyed by lowercase field IDs
- **FR-005**: Submission accessor methods MUST normalize input IDs to lowercase
- **FR-006**: XBRL Generator MUST use `field.xbrl_id` for XML element names
- **FR-007**: Taxonomy Loader MUST NOT load or require `semantic_mappings.yml`
- **FR-008**: Submission MUST provide `complete?` method returning boolean for all visible fields filled
- **FR-009**: Submission MUST provide `missing_fields` method returning list of unfilled visible field IDs

### Removed Functionality

- **REM-001**: `Field#name` attribute (semantic name) - removed
- **REM-002**: `Field#source_type` attribute - removed
- **REM-003**: `Field#required?`, `#computed?`, `#prefillable?`, `#entry_only?` methods - removed
- **REM-004**: `Questionnaire#computed_fields`, `#prefillable_fields`, `#entry_only_fields` methods - removed
- **REM-005**: `AmsfSurvey.validate()` method - removed (Arelle is authoritative validator)
- **REM-006**: `Validator` module - removed
- **REM-007**: Semantic name lookup in `Questionnaire#field()` - removed (only ID lookup)

### Key Entities

- **Field**: Represents a survey question. Key attributes: `id` (lowercase), `xbrl_id` (original casing), `type`, `label`, `depends_on`, `gate`
- **Questionnaire**: Collection of fields organized into sections. Provides field lookup by lowercase ID.
- **Submission**: Data container keyed by lowercase field IDs. Tracks completeness of visible fields.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can create submissions using field IDs without referencing any mapping file
- **SC-002**: XBRL output passes AMSF Strix portal validation (element names match taxonomy exactly)
- **SC-003**: Updating to a new AMSF taxonomy version requires only dropping in new XBRL files (no mapping updates)
- **SC-004**: All existing tests pass after updating field references from semantic names to IDs
- **SC-005**: Field lookup performance remains constant (O(1) hash lookup)

## Assumptions

- AMSF Strix portal requires exact casing match for XBRL element names
- All visible fields in the survey are legally required for obligated entities (no optional fields)
- Arelle with XULE rules is the authoritative validation mechanism
- Existing gate/visibility logic correctly determines which fields apply to a submission
