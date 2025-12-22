# Research: Submission & Validation

**Feature**: 003-submission-validation
**Date**: 2025-12-22
**Status**: Complete

---

## Research Questions

### 1. ActiveModel Integration Pattern

**Question**: How should Submission integrate with ActiveModel for validation semantics?

**Decision**: Use `ActiveModel::Model` and `ActiveModel::Attributes` for core attributes (entity_id, period, industry, year), but keep field data in a separate `@data` hash for dynamic field access.

**Rationale**:
- ActiveModel::Model provides `valid?`, `errors`, and standard Rails-compatible validation patterns
- ActiveModel::Attributes gives type coercion for core attributes
- Field data in separate hash allows dynamic field count (not predefined attributes)
- This matches the design doc's Section 7 example

**Alternatives Considered**:
1. Pure Ruby without ActiveModel - Rejected: would require reimplementing validation patterns
2. Define each field as an attribute - Rejected: fields are dynamic per questionnaire, not static
3. Use OpenStruct - Rejected: no validation support, memory overhead

---

### 2. Type Casting Strategy

**Question**: How should string inputs be converted to appropriate Ruby types?

**Decision**: Create a `TypeCaster` module with type-specific methods, delegated through `Field#cast`.

**Rationale**:
- Centralized casting logic in one place
- Field knows its type, can delegate to TypeCaster
- Supports all field types: integer, boolean, monetary, enum, string

**Type Mapping**:
| Field Type | Ruby Type | Casting Logic |
|------------|-----------|---------------|
| `:integer` | `Integer` | `value.to_i` (returns 0 for non-numeric) |
| `:monetary` | `BigDecimal` | `BigDecimal(value.to_s)` for precision |
| `:boolean` | `String` | Preserve "Oui"/"Non" (valid_values from schema) |
| `:enum` | `String` | Preserve value, validation checks valid_values |
| `:string` | `String` | `value.to_s` |

**Edge Cases**:
- `nil` → `nil` (no conversion)
- Empty string → `nil` for integer/monetary, preserved for string
- Already correct type → return as-is

**Alternatives Considered**:
1. Convert in Submission#[]= - Rejected: violates single responsibility
2. Use ActiveModel type coercion - Rejected: only works for defined attributes, not dynamic fields

---

### 3. Validation Rule Sources

**Question**: Where do validation rules come from?

**Decision**: Derive rules from existing Field metadata and questionnaire structure.

**Rule Sources**:
| Rule Type | Source |
|-----------|--------|
| Presence | `Field#required?` (already exists, returns `!computed?`) |
| Visibility | `Field#visible?(data)` (already exists, checks `depends_on`) |
| Range | New: Add `:min`/`:max` to Field from schema (if available) |
| Sum check | Deferred: requires computed field formulas (Phase 4+) |
| Enum validation | `Field#valid_values` (already exists) |

**Sum Check Deferral**: Sum validation requires parsing XULE formulas to extract relationships (e.g., `total = a + b + c`). This is complex and not required for MVP. Initial release validates presence, range, and enum only. Sum checks added when computed fields are implemented.

**Alternatives Considered**:
1. Parse XULE for all rules - Rejected: too complex for MVP, XuleParser already extracts gate rules only
2. Define rules in semantic_mappings.yml - Rejected: violates "taxonomy as source of truth"

---

### 4. ValidationResult Structure

**Question**: How should validation results be structured?

**Decision**: Immutable `ValidationResult` object with `valid?`, `complete?`, `errors`, and `warnings` methods.

**Structure**:
```ruby
ValidationResult.new(
  errors: [ValidationError, ...],
  warnings: [ValidationError, ...]
)

result.valid?     # => errors.empty?
result.complete?  # => no missing required fields
result.errors     # => frozen array
result.warnings   # => frozen array
```

**ValidationError Structure**:
```ruby
ValidationError.new(
  field: :field_id,      # Symbol
  rule: :presence,       # Symbol (:presence, :range, :enum, :conditional)
  message: "...",        # Human-readable
  severity: :error,      # :error or :warning
  context: {}            # Optional hash (expected:, actual:, min:, max:, etc.)
)
```

**Rationale**:
- Immutable results prevent accidental modification
- Separate errors/warnings for different UX treatment
- Context hash allows rule-specific details without subclasses

**Alternatives Considered**:
1. Use ActiveModel::Errors - Rejected: doesn't support warnings, limited context
2. Return raw hash - Rejected: no encapsulation, easy to misuse
3. Subclass per rule type - Rejected: over-engineering, context hash sufficient

---

### 5. Completeness vs Validation

**Question**: What's the difference between `complete?` and `valid?`?

**Decision**:
- `complete?` = All required visible fields have values (tracks progress)
- `valid?` = No validation errors (data quality)

**Key Distinction**:
- A submission can be complete but invalid (all fields filled, but with bad data)
- A submission can be incomplete but valid so far (partial data, no errors yet)
- Both are useful for different UX: progress bar vs. submit button enablement

**Implementation**:
- `Submission#complete?` → checks `missing_fields.empty?`
- `Submission#missing_fields` → required + visible + empty
- `ValidationResult#valid?` → checks `errors.empty?`
- `ValidationResult#complete?` → delegates to submission or tracks internally

---

### 6. Error Handling for Unknown Fields

**Question**: What happens when setting a value for a field not in the questionnaire?

**Decision**: Raise `UnknownFieldError` immediately on `[]=` call.

**Rationale**:
- Fail fast - catches typos and incorrect field names early
- Consistent with design doc behavior
- Alternative (silent ignore) would hide bugs

**Implementation**:
```ruby
def []=(field_id, value)
  field = questionnaire.field(field_id)
  raise UnknownFieldError, "Unknown field: #{field_id}" unless field
  @data[field_id] = field.cast(value)
end
```

---

## Resolved Items

All research questions resolved. No NEEDS CLARIFICATION markers remain.

## Dependencies Identified

1. **ActiveModel** - Already available in Ruby ecosystem, add to gemspec
2. **BigDecimal** - Ruby stdlib, no gem needed
3. **Existing Phase 2 classes** - Field, Questionnaire, Section available

## Implementation Notes

1. Start with P1 user stories (Submission creation, type casting)
2. Then P2 (completeness tracking, basic validation)
3. Defer sum checks to computed fields phase
4. Range validation added if/when schema provides min/max (future enhancement)

## References

- Design doc: `docs/plans/2025-12-21-amsf-survey-design.md` (Sections 4, 7)
- Ruby ActiveModel: https://api.rubyonrails.org/classes/ActiveModel.html
- BigDecimal precision: https://ruby-doc.org/stdlib/libdoc/bigdecimal/rdoc/BigDecimal.html
