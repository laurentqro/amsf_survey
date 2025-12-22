# Data Model: Taxonomy Loader

**Feature**: 002-taxonomy-loader
**Date**: 2025-12-21

## Overview

Three primary entities represent the survey structure: Questionnaire, Section, and Field. These are immutable value objects built by the taxonomy loader.

---

## Entity: Field

Represents a single survey question with all metadata.

### Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | Symbol | Yes | XBRL code (e.g., `:a1101`) |
| `name` | Symbol | Yes | Semantic name (e.g., `:total_unique_clients`) or XBRL code if unmapped |
| `type` | Symbol | Yes | Ruby type: `:integer`, `:boolean`, `:string`, `:monetary`, `:enum` |
| `xbrl_type` | String | Yes | Original XBRL type (e.g., `"xbrli:integerItemType"`) |
| `source_type` | Symbol | Yes | `:computed`, `:prefillable`, or `:entry_only` |
| `label` | String | Yes | French question text (HTML stripped) |
| `verbose_label` | String | No | Extended explanation (HTML stripped) |
| `valid_values` | Array | No | Allowed values for enum/boolean types |
| `section_id` | Symbol | Yes | Parent section identifier |
| `order` | Integer | Yes | Display order within section |
| `depends_on` | Hash | No | Gate dependencies: `{ field_id: required_value }` |
| `gate` | Boolean | Yes | True if this field controls other fields' visibility |

### Derived Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `boolean?` | Boolean | True if `type == :boolean` |
| `integer?` | Boolean | True if `type == :integer` |
| `monetary?` | Boolean | True if `type == :monetary` |
| `enum?` | Boolean | True if `type == :enum` |
| `computed?` | Boolean | True if `source_type == :computed` |
| `prefillable?` | Boolean | True if `source_type == :prefillable` |
| `entry_only?` | Boolean | True if `source_type == :entry_only` |
| `required?` | Boolean | True if has dependencies or is not computed |
| `visible?(data)` | Boolean | Evaluates gate dependencies against submission data |

### Validation Rules

- `id` must be a non-empty symbol
- `name` must be a non-empty symbol
- `type` must be one of: `:integer`, `:boolean`, `:string`, `:monetary`, `:enum`
- `source_type` must be one of: `:computed`, `:prefillable`, `:entry_only`
- `order` must be a positive integer
- If `type` is `:enum` or `:boolean`, `valid_values` must be present
- `depends_on` keys must reference existing field IDs

---

## Entity: Section

Represents a logical grouping of fields from a presentation link.

### Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | Symbol | Yes | Section identifier derived from role URI |
| `name` | String | Yes | Display name (e.g., `"Link_NoCountryDimension"`) |
| `order` | Integer | Yes | Position in questionnaire |
| `fields` | Array<Field> | Yes | Ordered collection of Field objects |

### Derived Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `visible?(data)` | Boolean | True if any field in section is visible |
| `field_count` | Integer | Number of fields in section |
| `empty?` | Boolean | True if no fields |

### Validation Rules

- `id` must be a non-empty symbol
- `order` must be a positive integer
- `fields` must be an array (can be empty)
- Fields must be in ascending `order` sequence

---

## Entity: Questionnaire

Container for an industry/year survey structure.

### Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `industry` | Symbol | Yes | Industry identifier (e.g., `:real_estate`) |
| `year` | Integer | Yes | Taxonomy year (e.g., `2025`) |
| `sections` | Array<Section> | Yes | Ordered collection of Section objects |

### Derived Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `fields` | Array<Field> | All fields across all sections |
| `field(id)` | Field or nil | Lookup by semantic name or XBRL code |
| `gate_fields` | Array<Field> | Fields where `gate == true` |
| `computed_fields` | Array<Field> | Fields where `source_type == :computed` |
| `prefillable_fields` | Array<Field> | Fields where `source_type == :prefillable` |
| `entry_only_fields` | Array<Field> | Fields where `source_type == :entry_only` |
| `field_count` | Integer | Total number of fields |
| `section_count` | Integer | Number of sections |

### Validation Rules

- `industry` must be a non-empty symbol
- `year` must be a 4-digit integer (1900-2099)
- `sections` must be an array with at least one section
- Sections must be in ascending `order` sequence

---

## Relationships

```
Questionnaire
    │
    ├──* Section (ordered by section.order)
    │       │
    │       └──* Field (ordered by field.order)
    │
    └── Cache key: [industry, year]
```

- Questionnaire has many Sections (one-to-many, ordered)
- Section has many Fields (one-to-many, ordered)
- Field may depend on other Fields via `depends_on` (many-to-many, self-referential)

---

## State Transitions

These entities are immutable. Once created by the Loader, they cannot be modified.

| State | Trigger | Result |
|-------|---------|--------|
| (none) | `AmsfSurvey.questionnaire(industry:, year:)` | Questionnaire loaded |
| Loaded | Same call with same params | Cached instance returned |
| Loaded | Call with different params | New Questionnaire loaded |

---

## Data Flow

```
Taxonomy Files                    Loader                      Objects
┌─────────────┐                 ┌───────────┐               ┌───────────────┐
│ .xsd        │──SchemaParser──▶│           │               │               │
│ _lab.xml    │──LabelParser───▶│  Loader   │───────────────▶ Questionnaire │
│ _pre.xml    │──PresParser────▶│           │               │   └─Sections  │
│ .xule       │──XuleParser────▶│           │               │      └─Fields │
│ mappings.yml│─────────────────▶           │               │               │
└─────────────┘                 └───────────┘               └───────────────┘
```

---

## Example Data

### Field Example

```ruby
Field.new(
  id: :a1101,
  name: :total_unique_clients,
  type: :integer,
  xbrl_type: "xbrli:integerItemType",
  source_type: :computed,
  label: "Veuillez indiquer le nombre total de clients uniques...",
  verbose_label: "L'expression « clients uniques » signifie que...",
  valid_values: nil,
  section_id: :no_country_dimension,
  order: 4,
  depends_on: { aACTIVE: "Oui" },
  gate: false
)
```

### Section Example

```ruby
Section.new(
  id: :no_country_dimension,
  name: "Link_NoCountryDimension",
  order: 1,
  fields: [field1, field2, field3]
)
```

### Questionnaire Example

```ruby
Questionnaire.new(
  industry: :real_estate,
  year: 2025,
  sections: [section1, section2, section3]
)
```
