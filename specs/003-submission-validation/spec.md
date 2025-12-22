# Feature Specification: Submission & Validation

**Feature Branch**: `003-submission-validation`
**Created**: 2025-12-22
**Status**: Draft
**Input**: Implement Submission class with ActiveModel integration for holding survey data, type casting, and Validator for presence checks, sum validation, conditional logic, and range validation.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create and Populate a Submission (Priority: P1)

A consumer application (CRM, API, CLI) creates a submission object to hold survey answers for a specific industry and reporting period. The submission stores field values with automatic type casting and provides access to the underlying questionnaire structure.

**Why this priority**: Without a submission container, there's no way to hold survey data. This is the foundational data structure for all other features.

**Independent Test**: Can be fully tested by creating a submission with sample data and verifying values are stored, type-cast correctly, and accessible. Delivers a working data container.

**Acceptance Scenarios**:

1. **Given** a registered industry (real_estate) and year (2025), **When** I create a submission with entity_id, period, and field data, **Then** the submission stores all values and provides access to the associated questionnaire.

2. **Given** a submission, **When** I set a field value as a string (e.g., "50"), **Then** the value is automatically cast to the correct type (integer 50) based on the field definition.

3. **Given** a submission, **When** I access a field value using bracket notation (submission[:field_name]), **Then** I receive the stored value or nil if not set.

4. **Given** a submission, **When** I try to set a value for an unknown field, **Then** an error is raised indicating the field doesn't exist.

---

### User Story 2 - Track Submission Completeness (Priority: P2)

A consumer application needs to show users their progress in completing the survey. The submission tracks which required fields are missing and calculates a completion percentage.

**Why this priority**: Users need feedback on their progress. Completeness tracking enables progress bars, "save and continue later" workflows, and identifying what's left to fill.

**Independent Test**: Can be tested by creating a partially-filled submission and checking completeness metrics. Delivers progress tracking functionality.

**Acceptance Scenarios**:

1. **Given** a submission with all required visible fields filled, **When** I check if complete, **Then** it returns true.

2. **Given** a submission with some required fields missing, **When** I check if complete, **Then** it returns false and I can retrieve the list of missing field IDs.

3. **Given** a submission with 5 of 10 required fields filled, **When** I request completion percentage, **Then** I receive 50.0.

4. **Given** a gate field answered "No" hiding 3 dependent fields, **When** I check missing fields, **Then** those hidden fields are not counted as missing.

5. **Given** a submission, **When** I request missing entry-only fields, **Then** I receive only the unfilled fields that require fresh user input (not prefillable or computed).

---

### User Story 3 - Validate Submission Data (Priority: P2)

A consumer application validates survey data before submission to the regulatory portal. The validator checks multiple rule categories and returns structured results with errors and warnings.

**Why this priority**: Validation prevents submission of incorrect data to the regulator. Catching errors early saves time and avoids rejection.

**Independent Test**: Can be tested by creating submissions with valid/invalid data and checking validation results. Delivers data quality assurance.

**Acceptance Scenarios**:

1. **Given** a complete submission with valid data, **When** I validate it, **Then** validation passes with no errors.

2. **Given** a submission missing required fields, **When** I validate it, **Then** I receive presence errors for each missing field.

3. **Given** a submission where a total field doesn't equal the sum of its components, **When** I validate it, **Then** I receive a sum check error with expected and actual values.

4. **Given** a percentage field with value 150, **When** I validate it, **Then** I receive a range error indicating the value exceeds the maximum (100).

5. **Given** a gate field answered "Yes" with dependent required fields empty, **When** I validate it, **Then** I receive conditional presence errors for the dependent fields.

---

### User Story 4 - Type Casting for Field Values (Priority: P1)

Field values submitted as strings (e.g., from web forms) are automatically converted to their correct types based on the field definition. This ensures data integrity and enables proper validation.

**Why this priority**: Web forms and APIs typically receive string input. Type casting is essential for correct storage, validation, and XBRL generation.

**Independent Test**: Can be tested by setting various string values and verifying correct type conversion. Delivers robust data handling.

**Acceptance Scenarios**:

1. **Given** an integer field, **When** I set value "123", **Then** it's stored as integer 123.

2. **Given** a boolean field, **When** I set value "Oui", **Then** it's stored as the boolean-equivalent value "Oui" (the valid enumeration value).

3. **Given** a monetary field, **When** I set value "1234.56", **Then** it's stored as the decimal/monetary value 1234.56.

4. **Given** an enum field with valid values ["Option A", "Option B"], **When** I set value "Option A", **Then** it's stored as "Option A".

5. **Given** an enum field, **When** I set an invalid value "Option X", **Then** either an error is raised or validation fails (captures invalid input).

---

### User Story 5 - Validation Result Details (Priority: P3)

Validation results provide detailed, actionable information about each issue found. Errors include the field, rule violated, human-readable message, and relevant values for debugging.

**Why this priority**: Good error messages enable users to fix problems quickly. Without details, debugging is frustrating.

**Independent Test**: Can be tested by validating invalid data and inspecting error structure. Delivers debuggable validation output.

**Acceptance Scenarios**:

1. **Given** a validation with errors, **When** I access errors, **Then** each error includes field ID, rule type, message, and severity.

2. **Given** a sum check failure, **When** I inspect the error, **Then** it includes the expected and actual values for comparison.

3. **Given** a range validation failure, **When** I inspect the error, **Then** it includes the value and the valid range.

4. **Given** validation with warnings (non-blocking issues), **When** I access warnings separately from errors, **Then** I can display them differently to users.

---

### Edge Cases

- What happens when setting a field value to nil? (Should clear the value)
- What happens when the industry is not registered? (Error during submission creation)
- What happens when the year is not supported? (Error during submission creation)
- How does validation handle empty/blank strings vs nil? (Treated as missing for required fields)
- What if a computed field's formula references missing values? (Computed as nil or zero, documented behavior)
- What if validation rules conflict? (All applicable errors are returned, not just the first)

---

## Requirements *(mandatory)*

### Functional Requirements

**Submission Object**:
- **FR-001**: System MUST allow creation of a Submission with industry, year, entity_id, period, and optional initial data.
- **FR-002**: System MUST validate that the industry is registered before accepting a submission.
- **FR-003**: System MUST validate that the year is supported for the given industry.
- **FR-004**: System MUST provide bracket notation access to field values (get and set).
- **FR-005**: System MUST automatically type-cast values based on field definitions when setting values.
- **FR-006**: System MUST raise an error when attempting to set a value for an unknown field.
- **FR-007**: System MUST provide access to the associated questionnaire for the submission's industry/year.

**Completeness Tracking**:
- **FR-008**: System MUST calculate whether all required visible fields are filled (complete? method).
- **FR-009**: System MUST return a list of missing required field IDs.
- **FR-010**: System MUST exclude hidden fields (gate-controlled) from missing field calculations.
- **FR-011**: System MUST calculate completion percentage based on required visible fields.
- **FR-012**: System MUST provide a list of missing entry-only fields specifically.

**Validation**:
- **FR-013**: System MUST validate presence of required fields.
- **FR-014**: System MUST validate sum checks (total equals sum of components).
- **FR-015**: System MUST validate conditional presence (fields required when gate is open).
- **FR-016**: System MUST validate range constraints (min/max values, percentages 0-100).
- **FR-017**: System MUST return a structured validation result with valid?, complete?, errors, and warnings.
- **FR-018**: System MUST include field ID, rule type, message, and severity in each error.
- **FR-019**: System MUST include expected/actual values for sum check errors.

**Type Casting**:
- **FR-020**: System MUST cast string inputs to integer for integer fields.
- **FR-021**: System MUST cast string inputs to decimal for monetary fields.
- **FR-022**: System MUST preserve valid enumeration values for boolean and enum fields.
- **FR-023**: System MUST handle nil values (clearing a field).

### Key Entities

- **Submission**: Container for survey response data. Holds entity_id, period, industry, year, and a hash of field values. Provides access to the questionnaire and tracks completeness.

- **ValidationResult**: Outcome of validating a submission. Contains valid? status, complete? status, arrays of errors and warnings. Immutable once created.

- **ValidationError**: Represents a single validation issue. Contains field ID, rule type (presence/sum_check/range/conditional), message, severity (error/warning), and optional context (expected/actual values).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Submissions can be created and populated in under 10 milliseconds for typical survey sizes (100-500 fields).

- **SC-002**: Validation of a complete submission executes in under 50 milliseconds.

- **SC-003**: Type casting correctly converts 100% of valid string inputs to their expected types.

- **SC-004**: Completion percentage accurately reflects the ratio of filled to required visible fields.

- **SC-005**: All validation errors include sufficient detail to identify and fix the issue without additional debugging.

- **SC-006**: Test coverage reaches 100% line coverage for submission and validation components.

---

## Assumptions

- The questionnaire, section, and field objects from Phase 2 are available and working.
- Field type information (integer, boolean, monetary, enum, string) is accessible from the questionnaire.
- Gate dependencies and visibility logic are already implemented in Field#visible?.
- Sum check formulas and range constraints will be derived from XULE rules or semantic mappings.
- Computed fields are handled in a later phase or are initially treated as regular fields.
- The system does not persist submissions (consumer responsibility).

---

## Out of Scope

- XBRL generation (Phase 4)
- Arelle integration for external validation (Phase 5)
- Submission persistence/serialization (consumer responsibility)
- Computed field formula evaluation (may be added in future iteration)
- Multi-entity submissions (single entity per submission)
- Historical validation (comparing against previous submissions)
