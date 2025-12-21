# Feature Specification: Taxonomy Loader

**Feature Branch**: `002-taxonomy-loader`
**Created**: 2025-12-21
**Status**: Draft
**Input**: User description: "Implement taxonomy loader that parses XBRL files (.xsd, _lab.xml, _pre.xml, .xule) and semantic_mappings.yml to build Questionnaire, Section, and Field objects"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Access Survey Questionnaire Structure (Priority: P1)

A developer building a CRM or API layer needs to access the complete survey structure for a specific industry and year. They call the gem's public API and receive a questionnaire object containing all sections, fields, and metadata needed to render forms or validate submissions.

**Why this priority**: This is the core capability - without questionnaire access, no other functionality works. Every consumer of the gem needs this.

**Independent Test**: Can be fully tested by calling `AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)` and verifying it returns a complete Questionnaire object with sections and fields.

**Acceptance Scenarios**:

1. **Given** a registered industry plugin with taxonomy files, **When** `AmsfSurvey.questionnaire(industry:, year:)` is called, **Then** a Questionnaire object is returned with all sections and fields populated from the taxonomy.

2. **Given** a questionnaire has been loaded, **When** the same call is made again, **Then** the cached instance is returned (same object reference).

3. **Given** an unregistered industry, **When** `questionnaire()` is called, **Then** an appropriate error is raised.

---

### User Story 2 - Query Field Metadata (Priority: P1)

A developer needs to access individual field metadata to render form inputs correctly - including labels, types, valid values, and visibility rules. They look up fields by semantic name or XBRL code.

**Why this priority**: Field metadata drives form rendering and validation. This is essential for any UI that displays survey questions.

**Independent Test**: Can be tested by loading a questionnaire and calling `questionnaire.field(:total_unique_clients)` to verify field properties.

**Acceptance Scenarios**:

1. **Given** a loaded questionnaire, **When** `field(id)` is called with a semantic name, **Then** the matching Field object is returned with all metadata (type, labels, source_type, etc.).

2. **Given** a loaded questionnaire, **When** `field(id)` is called with an XBRL code, **Then** the matching Field object is returned.

3. **Given** a field with enumerated values, **When** `field.valid_values` is accessed, **Then** the allowed values are returned (e.g., `["Oui", "Non"]`).

---

### User Story 3 - Filter Fields by Source Type (Priority: P2)

A developer building a pre-fill feature needs to identify which fields can be populated from external data sources versus which require fresh user input. They query fields by their source type.

**Why this priority**: Enables smart pre-population of forms. Important for UX but not blocking for basic functionality.

**Independent Test**: Can be tested by calling `questionnaire.prefillable_fields` and verifying only fields with `source_type: :prefillable` are returned.

**Acceptance Scenarios**:

1. **Given** a loaded questionnaire, **When** `prefillable_fields` is called, **Then** only fields with source_type `:prefillable` are returned.

2. **Given** a loaded questionnaire, **When** `computed_fields` is called, **Then** only fields with source_type `:computed` are returned.

3. **Given** a loaded questionnaire, **When** `entry_only_fields` is called, **Then** only fields with source_type `:entry_only` are returned.

---

### User Story 4 - Determine Field Visibility (Priority: P2)

A developer rendering a dynamic form needs to know which fields are visible based on gate question answers. When a user answers "No" to a gate question, dependent fields should be hidden.

**Why this priority**: Critical for correct form behavior. Gate questions control large sections of the survey.

**Independent Test**: Can be tested by calling `field.visible?(data)` with different gate answer combinations.

**Acceptance Scenarios**:

1. **Given** a field that depends on a gate question, **When** `visible?(data)` is called with the gate answer matching the dependency, **Then** true is returned.

2. **Given** a field that depends on a gate question, **When** `visible?(data)` is called with a non-matching gate answer, **Then** false is returned.

3. **Given** a field with no dependencies, **When** `visible?(data)` is called, **Then** true is always returned.

---

### User Story 5 - Navigate Sections (Priority: P3)

A developer building a multi-step form wizard needs to iterate through survey sections in presentation order, displaying fields grouped logically.

**Why this priority**: Enhances form UX with logical groupings. Can be deferred if single-page form is acceptable initially.

**Independent Test**: Can be tested by iterating `questionnaire.sections` and verifying each section contains its expected fields in order.

**Acceptance Scenarios**:

1. **Given** a loaded questionnaire, **When** `sections` is accessed, **Then** Section objects are returned in presentation order.

2. **Given** a section, **When** `fields` is accessed, **Then** Field objects are returned in display order within that section.

3. **Given** submission data, **When** `section.visible?(data)` is called, **Then** true is returned only if at least one field in the section is visible.

---

### Edge Cases

- What happens when a taxonomy file is missing? System raises `MissingTaxonomyFileError` with the file path.
- What happens when XML is malformed? System raises `MalformedTaxonomyError` with parse details.
- What happens when `semantic_mappings.yml` is missing? System raises `MissingSemanticMappingError`.
- What happens when a field has no label in the taxonomy? System uses the XBRL code as a fallback label.
- What happens when a field is not in semantic_mappings.yml? System uses XBRL code as name and defaults to `source_type: :entry_only`.
- What happens with nested gate dependencies (A controls B, B controls C)? All dependencies in the chain must be satisfied for a field to be visible.
- What happens when a section has no visible fields? The section reports `visible?: false`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST parse XBRL schema files (.xsd) to extract field IDs, types, and enumerated values.
- **FR-002**: System MUST parse label files (_lab.xml) to extract French labels (standard and verbose).
- **FR-003**: System MUST parse presentation files (_pre.xml) to extract section groupings and field ordering.
- **FR-004**: System MUST parse XULE files (.xule) to extract gate question dependencies.
- **FR-005**: System MUST read semantic_mappings.yml to map XBRL codes to semantic field names and source types.
- **FR-006**: System MUST provide a public API `AmsfSurvey.questionnaire(industry:, year:)` that returns a Questionnaire object.
- **FR-007**: System MUST cache loaded questionnaires to avoid re-parsing on subsequent calls.
- **FR-008**: System MUST expose field lookup by both semantic name and XBRL code via `questionnaire.field(id)`.
- **FR-009**: System MUST expose filtering methods for fields by source type (`computed_fields`, `prefillable_fields`, `entry_only_fields`).
- **FR-010**: System MUST expose a `visible?(data)` method on Field that evaluates gate dependencies.
- **FR-011**: System MUST map XBRL types to Ruby-friendly symbols (`:integer`, `:boolean`, `:string`, `:monetary`, `:enum`).
- **FR-012**: System MUST preserve original XBRL type on Field for downstream XBRL generation.
- **FR-013**: System MUST strip HTML from labels while preserving readable text.
- **FR-014**: System MUST raise specific errors for missing files, malformed XML, and missing mappings.
- **FR-015**: System MUST handle fields not in semantic_mappings.yml by using XBRL code as name and defaulting source_type.

### Key Entities

- **Questionnaire**: Container for an industry/year survey. Holds sections and provides field lookup and filtering methods.
- **Section**: Logical grouping of fields from a presentation link. Has ID, name, order, and collection of fields.
- **Field**: Individual survey question with all metadata (ID, name, type, labels, source_type, dependencies, etc.).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Questionnaire loading completes in under 2 seconds for a taxonomy with 500+ fields.
- **SC-002**: Second call to `questionnaire()` with same parameters returns in under 10 milliseconds (cached).
- **SC-003**: All fields from the taxonomy schema are represented in the Questionnaire object (100% field coverage).
- **SC-004**: Field lookup by semantic name or XBRL code succeeds for any field in the questionnaire.
- **SC-005**: Gate question visibility logic correctly evaluates all dependency chains in the taxonomy.
- **SC-006**: 100% test coverage for all parser classes and data models.

## Assumptions

- Taxonomy files follow the standard XBRL 2.1 format as provided by AMSF.
- The XULE file format is consistent across years (same DSL syntax for gate rules).
- French is the only language needed for labels (no multi-language support required).
- The semantic_mappings.yml file will be maintained manually by the development team.
- Fields not mapped in semantic_mappings.yml are still useful with their XBRL codes.
