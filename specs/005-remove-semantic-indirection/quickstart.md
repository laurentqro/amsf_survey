# Quickstart: Using Field IDs Directly

## Overview

This feature removes semantic name indirection. You now use XBRL element IDs directly (lowercase) instead of semantic names.

## Before vs After

### Creating a Submission

**Before (semantic names):**
```ruby
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "MY_AGENCY_001",
  period: Date.new(2025, 12, 31),
  data: {
    has_activity: true,
    total_clients: 42,
    clients_nationals: 10
  }
)
```

**After (field IDs):**
```ruby
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "MY_AGENCY_001",
  period: Date.new(2025, 12, 31),
  data: {
    aactive: true,
    a1101: 42,
    a1102: 10
  }
)
```

### Accessing Fields

**Before:**
```ruby
questionnaire.field(:total_clients)
submission[:total_clients]
```

**After:**
```ruby
questionnaire.field(:a1101)
submission[:a1101]
```

### Field Attributes

**Before:**
```ruby
field = questionnaire.field(:total_clients)
field.id      # => :a1101 (XBRL code)
field.name    # => :total_clients (semantic name)
```

**After:**
```ruby
field = questionnaire.field(:a1101)
field.id      # => :a1101 (lowercase)
field.xbrl_id # => :a1101 (original casing for XBRL output)

# For mixed-case IDs:
field = questionnaire.field(:aactive)
field.id      # => :aactive (lowercase)
field.xbrl_id # => :aACTIVE (original casing)
```

## Removed Features

### No More Ruby Validation

**Before:**
```ruby
result = AmsfSurvey.validate(submission)
result.valid?
result.errors
```

**After:**
Use Arelle with XULE rules for validation. Ruby-side validation is removed.

### No More source_type Methods

**Before:**
```ruby
field.source_type  # => :entry_only, :prefillable, :computed
field.computed?
field.prefillable?
field.entry_only?
field.required?
```

**After:**
These methods no longer exist. All visible fields are required by law.

### No More Filtered Field Lists

**Before:**
```ruby
questionnaire.computed_fields
questionnaire.prefillable_fields
questionnaire.entry_only_fields
```

**After:**
These methods no longer exist. Use `questionnaire.fields` and filter as needed.

## Still Available

### Progress Tracking

```ruby
submission.complete?      # => true/false
submission.missing_fields # => [:a1101, :a1102, ...]
```

### Gate Visibility

```ruby
field.visible?(data)      # => true/false based on gate dependencies
questionnaire.gate_fields # => fields that control visibility
```

### XBRL Generation

```ruby
xml = AmsfSurvey.to_xbrl(submission)
# Output uses original casing: <strix:aACTIVE>Oui</strix:aACTIVE>
```

## Migration Checklist

1. Replace semantic names with field IDs in all `data:` hashes
2. Replace semantic names in all `field()` and `submission[]` calls
3. Remove any calls to `AmsfSurvey.validate()`
4. Remove any calls to `field.name` or `field.source_type`
5. Remove any calls to `computed_fields`, `prefillable_fields`, `entry_only_fields`
6. Use `field.xbrl_id` if you need the original casing
