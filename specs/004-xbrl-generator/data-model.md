# Data Model: XBRL Generator

**Feature Branch**: `004-xbrl-generator`
**Created**: 2025-12-22

## Overview

The XBRL Generator transforms a `Submission` object into an XBRL instance XML string. This document defines the internal data structures used during generation.

## Entities

### Generator (New)

Primary class responsible for building XBRL instance documents.

**Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `submission` | `Submission` | The source submission object |
| `options` | `Hash` | Generation options (pretty, include_empty) |

**Derived Properties**:
| Property | Type | Source |
|----------|------|--------|
| `questionnaire` | `Questionnaire` | `submission.questionnaire` |
| `taxonomy_namespace` | `String` | `questionnaire.taxonomy_namespace` |
| `entity_id` | `String` | `submission.entity_id` |
| `period` | `Date` | `submission.period` |

**Methods**:
| Method | Return Type | Description |
|--------|-------------|-------------|
| `generate` | `String` | Build and return XBRL XML |

---

### Questionnaire (Existing - Enhancement)

Needs new attribute to store the taxonomy namespace.

**New Attribute**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `taxonomy_namespace` | `String` | Target namespace from XSD (e.g., `https://amlcft.amsf.mc/dcm/DTS/strix_Real_Estate_AML_CFT_survey_2025/fr`) |

**Source**: Extracted from XSD `targetNamespace` attribute during taxonomy loading.

---

### Field (Existing - Enhancement)

Needs XBRL code access for fact element names.

**Existing Attribute (already available)**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | `Symbol` | The XBRL code as symbol (e.g., `:a1101`) |

**Note**: The Field `id` is already the XBRL code. No new attribute needed - just convert to string for XML element name.

---

## XBRL Output Structure

### Document Hierarchy

```
XBRL Instance Document
├── XML Declaration
├── Root Element (xbrli:xbrl)
│   ├── Namespace Declarations
│   ├── Schema Reference (link:schemaRef)
│   ├── Context (xbrli:context)
│   │   ├── Entity (xbrli:entity)
│   │   │   └── Identifier (xbrli:identifier)
│   │   └── Period (xbrli:period)
│   │       └── Instant (xbrli:instant)
│   └── Facts (strix:{field_id})
│       ├── contextRef attribute
│       ├── decimals attribute (numeric only)
│       └── Value content
```

### Namespace Registry

| Prefix | URI | Purpose |
|--------|-----|---------|
| `xbrli` | `http://www.xbrl.org/2003/instance` | XBRL instance elements |
| `link` | `http://www.xbrl.org/2003/linkbase` | Schema references |
| `xlink` | `http://www.w3.org/1999/xlink` | XLink attributes |
| `strix` | `{taxonomy_namespace}` | Taxonomy-specific facts |

---

## Value Formatting

### Type → XBRL Format

| Ruby Type | Field Type | XBRL Format | Decimals |
|-----------|------------|-------------|----------|
| `true` | `:boolean` | `"Oui"` | (omit) |
| `false` | `:boolean` | `"Non"` | (omit) |
| `Integer` | `:integer` | `"123"` | `"0"` |
| `BigDecimal` | `:monetary` | `"1234.56"` | `"2"` |
| `BigDecimal` | `:percentage` | `"75.50"` | `"2"` |
| `String` | `:string` | `"text"` | (omit) |
| `String` | `:enum` | `"EnumValue"` | (omit) |
| `nil` | any | `""` | (omit if include_empty: false) |

---

## State Transitions

```
Submission (input)
    │
    ▼
Generator.new(submission, options)
    │
    ├── Build namespaces
    ├── Build context
    ├── Collect visible fields
    ├── Format values
    ├── Build facts
    │
    ▼
XBRL XML String (output)
```

---

## Validation Rules

The Generator does NOT validate submissions. Validation is the caller's responsibility via `AmsfSurvey.validate(submission)`.

However, the Generator does:
- Skip fields hidden by gate rules (`field.visible?(data)`)
- Skip nil values if `include_empty: false`
- Escape XML special characters automatically (Nokogiri handles this)

---

## Integration Points

### Existing Classes Used

| Class | Usage |
|-------|-------|
| `Submission` | Source data, entity_id, period, industry, year |
| `Questionnaire` | Field metadata, taxonomy_namespace |
| `Field` | Type info, visibility rules, XBRL code (id) |

### New Public API

```ruby
# Primary entry point (module method)
AmsfSurvey.to_xbrl(submission)
AmsfSurvey.to_xbrl(submission, pretty: true)
AmsfSurvey.to_xbrl(submission, include_empty: false)
AmsfSurvey.to_xbrl(submission, pretty: true, include_empty: false)
```

### Registry Integration

Add `to_xbrl` method to `AmsfSurvey` module (in registry.rb) that delegates to `Generator`.
