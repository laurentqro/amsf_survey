# Remove Semantic Name Indirection

**Date:** 2025-01-24
**Status:** Approved

## Context

The amsf_survey gem currently uses semantic field names (like `total_clients`, `high_risk_clients`) that map to XBRL element IDs (like `a1101`, `a1102`). This mapping is defined in `semantic_mappings.yml`.

The consuming application (immo_crm) has realized this indirection adds friction without reducing coupling. When AMSF updates the questionnaire, the desired workflow is:
1. Drop the new XBRL file into the gem
2. Add a method to the CRM

Instead of also having to update `semantic_mappings.yml`.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Case handling | Lowercase at accessor, preserve original for XBRL | Ruby method compatibility + XBRL compliance |
| Semantic mappings | Remove entirely | No value in maintaining the indirection |
| `source_type` | Remove | Not useful; all visible fields are legally required |
| `Field#name` | Remove | Single identifier (`id`) is clearer |
| Ruby validation | Remove entirely | Arelle is authoritative using XBRL/XULE rules |
| `complete?`/`missing_fields` | Keep | Useful for CRM progress indicators |
| Gate/visibility logic | Keep | Needed for progress tracking and XBRL output |

## Changes

### Field Class

**Remove:**
- `name` attribute
- `source_type` attribute
- `required?`, `computed?`, `prefillable?`, `entry_only?` methods

**Add:**
- `xbrl_id` - original casing for XBRL generation

**Change:**
- `id` returns lowercase symbol

```ruby
class Field
  attr_reader :id, :type, :xbrl_type, :label, ...

  def initialize(id:, ...)
    @xbrl_id = id                    # Original casing for XBRL output
    @id = id.to_s.downcase.to_sym    # Lowercase for API
  end

  def xbrl_id
    @xbrl_id  # Original casing: :aACTIVE
  end

  def id
    @id       # Lowercase: :aactive
  end
end
```

### Questionnaire Class

**Remove:**
- Dual indexing (no more semantic name lookup)
- `computed_fields`, `prefillable_fields`, `entry_only_fields` methods

**Change:**
- `field()` normalizes input to lowercase before lookup

```ruby
class Questionnaire
  def field(id)
    @field_index[id.to_s.downcase.to_sym]
  end

  def build_field_index
    fields.each_with_object({}) do |field, index|
      index[field.id] = field
    end
  end

  def gate_fields  # Keep
  end
end
```

### Submission Class

**Change:**
- All field ID inputs normalized to lowercase
- Data hash uses lowercase keys

```ruby
class Submission
  def [](field_id)
    field_id = field_id.to_s.downcase.to_sym
    validate_field!(field_id)
    @data[field_id]
  end

  def []=(field_id, value)
    field_id = field_id.to_s.downcase.to_sym
    field = validate_field!(field_id)
    @data[field_id] = field.cast(value)
  end
end
```

### XBRL Generator

**Change:**
- Use `field.xbrl_id` for XML element names (preserves original casing)

```ruby
def build_fact(doc, parent, strix_ns, field, value)
  fact = Nokogiri::XML::Node.new(field.xbrl_id.to_s, doc)
  # ...
end
```

### Taxonomy Loader

**Remove:**
- Loading of `semantic_mappings.yml`
- `mappings` parameter from `build_field`
- `name` and `source_type` field construction

### Files to Remove

- `amsf_survey/lib/amsf_survey/validator.rb`
- `amsf_survey-real_estate/taxonomies/2025/semantic_mappings.yml`
- Test fixtures for semantic_mappings.yml

### Public API to Remove

- `AmsfSurvey.validate()` method

## Public API After Changes

```ruby
# Build with lowercase field IDs
submission = AmsfSurvey.build_submission(
  industry: :real_estate, year: 2025,
  entity_id: "X", period: Date.new(2025, 12, 31),
  data: { aactive: true, a1101: 42 }
)

# No Ruby validation - use Arelle externally

# Access fields by lowercase ID
questionnaire.field(:a1101)
submission[:a1101]

# XBRL output preserves original casing
AmsfSurvey.to_xbrl(submission)  # => <strix:aACTIVE>...</strix:aACTIVE>
```

## Out of Scope

- No changes to XBRL generation logic (beyond using `xbrl_id`)
- No changes to taxonomy loading (beyond removing semantic mappings)
- No changes to gate/visibility logic
