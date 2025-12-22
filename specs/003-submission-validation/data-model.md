# Data Model: Submission & Validation

**Feature**: 003-submission-validation
**Date**: 2025-12-22

---

## Entity Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Submission                               │
│  - entity_id: String                                             │
│  - period: Date                                                  │
│  - industry: Symbol                                              │
│  - year: Integer                                                 │
│  - data: Hash{Symbol => Any}                                     │
├─────────────────────────────────────────────────────────────────┤
│  + questionnaire → Questionnaire                                 │
│  + [](field_id) → value                                         │
│  + []=(field_id, value)                                         │
│  + complete? → Boolean                                          │
│  + completion_percentage → Float                                 │
│  + missing_fields → Array<Symbol>                               │
│  + missing_entry_only_fields → Array<Symbol>                    │
│  + validate → ValidationResult                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ produces
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ValidationResult                            │
│  - errors: Array<ValidationError>                                │
│  - warnings: Array<ValidationError>                              │
├─────────────────────────────────────────────────────────────────┤
│  + valid? → Boolean                                             │
│  + complete? → Boolean                                          │
│  + error_count → Integer                                        │
│  + warning_count → Integer                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ contains
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ValidationError                             │
│  - field: Symbol                                                │
│  - rule: Symbol (:presence, :range, :enum, :conditional)        │
│  - message: String                                              │
│  - severity: Symbol (:error, :warning)                          │
│  - context: Hash (optional, rule-specific data)                 │
├─────────────────────────────────────────────────────────────────┤
│  + to_h → Hash                                                  │
│  + to_s → String                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Entity Details

### Submission

**Purpose**: Container for survey response data. Holds all field values for a single entity's regulatory submission.

**Attributes**:

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `entity_id` | String | Yes | Unique identifier for the reporting entity |
| `period` | Date | Yes | Reporting period end date (e.g., 2025-12-31) |
| `industry` | Symbol | Yes | Registered industry (e.g., `:real_estate`) |
| `year` | Integer | Yes | Taxonomy year (e.g., 2025) |
| `data` | Hash | No | Field values keyed by semantic field ID |

**Relationships**:
- Belongs to one `Questionnaire` (derived from industry + year)
- Produces one `ValidationResult` when validated

**Validation Rules**:
- `entity_id` must be present and non-empty
- `period` must be a valid date
- `industry` must be registered in AmsfSurvey
- `year` must be supported for the industry

**State Transitions**: None (immutable once created, data hash mutable)

---

### ValidationResult

**Purpose**: Immutable outcome of validating a submission. Separates errors (blocking) from warnings (informational).

**Attributes**:

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `errors` | Array<ValidationError> | Yes | Blocking validation issues |
| `warnings` | Array<ValidationError> | Yes | Non-blocking issues |

**Computed Properties**:
- `valid?` → `errors.empty?`
- `complete?` → No missing required fields (from errors)
- `error_count` → `errors.size`
- `warning_count` → `warnings.size`

**Immutability**: Arrays are frozen on creation.

---

### ValidationError

**Purpose**: Represents a single validation issue with full context for debugging and display.

**Attributes**:

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `field` | Symbol | Yes | Field ID where error occurred |
| `rule` | Symbol | Yes | Rule type that failed |
| `message` | String | Yes | Human-readable error message |
| `severity` | Symbol | Yes | `:error` or `:warning` |
| `context` | Hash | No | Rule-specific details |

**Rule Types and Context**:

| Rule | Context Keys | Example |
|------|--------------|---------|
| `:presence` | (none) | Field is required but missing |
| `:range` | `:value`, `:min`, `:max` | Value outside allowed range |
| `:enum` | `:value`, `:valid_values` | Value not in allowed set |
| `:conditional` | `:gate_field`, `:gate_value` | Required when gate is open |
| `:sum_check` | `:expected`, `:actual` | Total doesn't match sum (future) |

---

### TypeCaster (Module)

**Purpose**: Converts string inputs to appropriate Ruby types based on field definition.

**Methods**:

| Method | Input | Output | Notes |
|--------|-------|--------|-------|
| `cast(value, field)` | Any, Field | Typed value | Delegates to type-specific method |
| `cast_integer(value)` | String/Integer | Integer/nil | Returns nil for non-numeric |
| `cast_monetary(value)` | String/Numeric | BigDecimal/nil | Preserves precision |
| `cast_string(value)` | Any | String | Simple to_s |
| `cast_boolean(value)` | String | String | Preserves "Oui"/"Non" |
| `cast_enum(value)` | String | String | Preserves value |

---

### Validator (Module/Class)

**Purpose**: Orchestrates validation of a submission against all applicable rules.

**Methods**:

| Method | Input | Output | Description |
|--------|-------|--------|-------------|
| `validate(submission)` | Submission | ValidationResult | Runs all rules |
| `validate_presence(submission)` | Submission | Array<ValidationError> | Required field checks |
| `validate_ranges(submission)` | Submission | Array<ValidationError> | Min/max checks |
| `validate_enums(submission)` | Submission | Array<ValidationError> | Valid value checks |
| `validate_conditionals(submission)` | Submission | Array<ValidationError> | Gate-dependent checks |

---

## Relationships Diagram

```
┌──────────────┐         ┌─────────────────┐
│   Registry   │ creates │   Submission    │
│              │────────▶│                 │
│ .build_sub() │         │ .questionnaire ─┼──────┐
└──────────────┘         │ .data           │      │
                         │ .validate()     │      │
                         └────────┬────────┘      │
                                  │               │
                         produces │               │ references
                                  ▼               │
                    ┌─────────────────────┐       │
                    │  ValidationResult   │       │
                    │                     │       │
                    │  .errors[]          │       │
                    │  .warnings[]        │       │
                    └─────────────────────┘       │
                                                  │
                    ┌─────────────────────┐       │
                    │   Questionnaire     │◀──────┘
                    │   (from Phase 2)    │
                    │                     │
                    │  .field(id)         │
                    │  .fields            │
                    └─────────────────────┘
```

---

## Field Type Mapping

| Schema Type | Ruby Type | Cast From | Validation |
|-------------|-----------|-----------|------------|
| `:integer` | Integer | String, Integer | Range (if defined) |
| `:monetary` | BigDecimal | String, Float, Integer | Range (if defined) |
| `:string` | String | Any | None |
| `:boolean` | String | String | Enum (valid_values) |
| `:enum` | String | String | Enum (valid_values) |

---

## Error Messages

Standard message templates for consistency:

| Rule | Template |
|------|----------|
| Presence | "Field '{field_label}' is required" |
| Range (min) | "Field '{field_label}' must be at least {min}" |
| Range (max) | "Field '{field_label}' must be at most {max}" |
| Enum | "Field '{field_label}' must be one of: {valid_values}" |
| Conditional | "Field '{field_label}' is required when '{gate_label}' is '{gate_value}'" |
