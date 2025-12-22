# Feature Specification: XBRL Generator

**Feature Branch**: `004-xbrl-generator`
**Created**: 2025-12-22
**Status**: Draft
**Input**: User description: "XBRL Generator - Generate XBRL instance XML documents from validated Submission objects for Strix portal upload. Should handle contexts, facts, namespaces, and support options like pretty printing."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate XBRL from Complete Submission (Priority: P1)

A developer has a fully validated Submission object with all required fields populated. They need to generate an XBRL instance document that can be uploaded to the Monaco AMSF Strix portal for regulatory compliance.

**Why this priority**: This is the core value proposition - without XBRL generation, the gem cannot fulfill its primary purpose of regulatory submission.

**Independent Test**: Can be fully tested by creating a Submission with sample data and verifying the output XML is well-formed XBRL with correct structure, namespaces, and fact values.

**Acceptance Scenarios**:

1. **Given** a valid Submission with entity_id, period, industry, year, and field data, **When** calling the generator, **Then** return a well-formed XBRL instance XML string with proper namespaces, context, and facts.

2. **Given** a Submission with boolean fields (Oui/Non values), **When** generating XBRL, **Then** output the original French values ("Oui"/"Non") as fact content.

3. **Given** a Submission with integer and monetary fields, **When** generating XBRL, **Then** include appropriate `decimals` attribute (0 for integers, 2 for monetary).

4. **Given** a Submission with enum fields, **When** generating XBRL, **Then** output the selected enum value as fact content.

---

### User Story 2 - Control Output Formatting (Priority: P2)

A developer wants to inspect or debug the generated XBRL by viewing it in a human-readable format, or needs compact output for efficient transmission.

**Why this priority**: Pretty printing aids debugging and development but isn't required for core functionality.

**Independent Test**: Generate XBRL with and without pretty printing option and verify formatting differences.

**Acceptance Scenarios**:

1. **Given** a Submission and `pretty: false` (default), **When** generating XBRL, **Then** output minified XML without extra whitespace or indentation.

2. **Given** a Submission and `pretty: true`, **When** generating XBRL, **Then** output indented XML with readable formatting.

---

### User Story 3 - Handle Empty and Nil Fields (Priority: P2)

A developer has a Submission where some optional fields are empty or nil, and needs control over whether these appear in the XBRL output.

**Why this priority**: Different regulatory systems may have different requirements for empty fields.

**Independent Test**: Generate XBRL with empty fields using both include/exclude options and verify output.

**Acceptance Scenarios**:

1. **Given** a Submission with nil field values and `include_empty: true` (default), **When** generating XBRL, **Then** include facts with empty content for nil fields.

2. **Given** a Submission with nil field values and `include_empty: false`, **When** generating XBRL, **Then** omit facts for nil fields entirely.

---

### User Story 4 - Generate from Incomplete Submission (Priority: P3)

A developer wants to generate XBRL for preview purposes even when the submission has validation warnings or missing optional fields.

**Why this priority**: Useful for preview/debugging workflows but secondary to core generation.

**Independent Test**: Generate XBRL from an incomplete submission and verify it still produces valid XML structure.

**Acceptance Scenarios**:

1. **Given** a Submission with missing optional fields, **When** generating XBRL, **Then** successfully generate XML with available data.

2. **Given** a Submission that fails validation, **When** generating XBRL without validation check, **Then** still produce XML output (caller's responsibility to validate first).

---

### Edge Cases

- What happens when Submission has no field data? Generate valid XBRL with context but no facts.
- What happens when entity_id contains special XML characters? Properly escape all values.
- What happens when period date is in wrong format? Raise clear error indicating expected format.
- How are hidden fields (gate-controlled) handled? Include only visible fields based on gate question answers.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST generate valid XBRL instance XML conforming to XBRL 2.1 specification.
- **FR-002**: System MUST include proper XML declaration with UTF-8 encoding.
- **FR-003**: System MUST include all required XBRL namespaces (xbrli, link, xlink, and taxonomy-specific namespace).
- **FR-004**: System MUST generate a context element with entity identifier and period instant.
- **FR-005**: System MUST generate fact elements for each field value, using the XBRL code as element name.
- **FR-006**: System MUST reference the correct context in each fact element via `contextRef` attribute.
- **FR-007**: System MUST include `decimals` attribute on numeric facts (0 for integers, 2 for monetary).
- **FR-008**: System MUST properly escape special XML characters in all content.
- **FR-009**: System MUST support `pretty: true/false` option for output formatting.
- **FR-010**: System MUST support `include_empty: true/false` option for nil field handling.
- **FR-011**: System MUST only include visible fields (respecting gate question visibility rules).
- **FR-012**: System MUST derive the taxonomy namespace from the questionnaire's industry and year.

### Key Entities

- **XBRL Instance Document**: The complete XML document with declaration, namespaces, context, and facts.
- **Context**: Identifies the entity and reporting period; referenced by all facts.
- **Fact**: Individual data point with element name (XBRL code), value, context reference, and attributes.
- **Namespace**: XML namespace declarations mapping prefixes to taxonomy URIs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Generated XBRL documents pass Strix portal upload validation without modification.
- **SC-002**: Generation completes in under 100ms for submissions with up to 500 fields.
- **SC-003**: Output XML is well-formed and parseable by standard XML parsers.
- **SC-004**: 100% of field types (boolean, integer, monetary, string, enum) are correctly serialized.
- **SC-005**: Gate-controlled field visibility is correctly reflected (hidden fields excluded from output).

## Assumptions

- The Strix portal expects XBRL 2.1 format with instant periods (not duration).
- Entity identifier scheme is `https://amlcft.amsf.mc` (Monaco AMSF standard).
- Boolean fields retain French values ("Oui"/"Non") in the XBRL output.
- Monetary values use 2 decimal places; integer values use 0 decimals.
- The taxonomy namespace follows the pattern `https://amlcft.amsf.mc/dcm/DTS/strix_{Industry}_AML_CFT_survey_{Year}/fr`.
- Context ID follows a predictable pattern like `ctx_{year}` or similar.
- Submissions are expected to be validated before generation (generator does not validate).

## Out of Scope

- Arelle validation of generated XBRL (separate feature).
- Writing XBRL to file (caller's responsibility).
- Multi-period or dimensional XBRL (future enhancement if needed).
- XBRL-JSON or other alternative formats.
