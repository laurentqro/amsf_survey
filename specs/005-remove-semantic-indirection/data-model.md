# Data Model: Remove Semantic Name Indirection

## Entity Changes

### Field (Modified)

**Before:**
```ruby
class Field
  attr_reader :id,           # Symbol - XBRL element code (:a1101, :aACTIVE)
              :name,         # Symbol - semantic name (:total_clients, :has_activity)
              :type,         # Symbol - data type
              :xbrl_type,    # String - XBRL type specification
              :source_type,  # Symbol - :entry_only, :prefillable, :computed
              :label,        # String - French label
              :verbose_label,# String - extended explanation
              :valid_values, # Array - allowed enum values
              :depends_on,   # Hash - gate dependencies
              :gate,         # Boolean - is this a gate field?
              :section_id,   # Symbol - parent section
              :order,        # Integer - display order
              :min, :max     # Range constraints
end
```

**After:**
```ruby
class Field
  attr_reader :xbrl_id,      # Symbol - original XBRL element code (:aACTIVE)
              :id,           # Symbol - lowercase version for API (:aactive)
              :type,         # Symbol - data type
              :xbrl_type,    # String - XBRL type specification
              :label,        # String - French label
              :verbose_label,# String - extended explanation
              :valid_values, # Array - allowed enum values
              :depends_on,   # Hash - gate dependencies
              :gate,         # Boolean - is this a gate field?
              :section_id,   # Symbol - parent section
              :order,        # Integer - display order
              :min, :max     # Range constraints
end
```

**Removed Attributes:**
- `name` - semantic name no longer exists
- `source_type` - not useful (all visible fields are required)

**Removed Methods:**
- `required?` - removed (all visible fields are required)
- `computed?` - removed
- `prefillable?` - removed
- `entry_only?` - removed

**Added Attributes:**
- `xbrl_id` - stores original casing for XBRL generation

**Changed Behavior:**
- `id` now returns lowercase symbol derived from original XBRL code

### Questionnaire (Modified)

**Before:**
```ruby
class Questionnaire
  def field(id)
    @field_index[id.to_sym]  # Dual lookup by ID or semantic name
  end

  def computed_fields
  def prefillable_fields
  def entry_only_fields
end
```

**After:**
```ruby
class Questionnaire
  def field(id)
    @field_index[id.to_s.downcase.to_sym]  # Single lookup by lowercase ID
  end
end
```

**Removed Methods:**
- `computed_fields`
- `prefillable_fields`
- `entry_only_fields`

**Changed Behavior:**
- `field()` normalizes input to lowercase before lookup
- `build_field_index` creates single-entry index (no dual indexing)

### Submission (Modified)

**Changed Behavior:**
- Data hash keyed by lowercase field IDs
- `[]` and `[]=` normalize input to lowercase
- Input data in `initialize` normalized to lowercase keys

### Generator (Modified)

**Changed Behavior:**
- Uses `field.xbrl_id` instead of `field.id` for XML element names
- Ensures XBRL output preserves original casing

### Validator (Deleted)

The entire `Validator` module is removed. Arelle with XULE rules is the authoritative validator.

## State Transitions

No state machines in this feature. Fields are immutable value objects.

## Validation Rules

- All visible fields are required (enforced by Arelle, not Ruby)
- Field lookup requires valid field ID (raises error if not found)
- Data keys are normalized to lowercase symbols

## Relationships

```
Questionnaire 1──* Section 1──* Field
     │
     └── field_index: {lowercase_id => Field}

Submission *──1 Questionnaire
     │
     └── data: {lowercase_id => value}
```
