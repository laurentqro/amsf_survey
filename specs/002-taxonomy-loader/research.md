# Research: Taxonomy Loader

**Feature**: 002-taxonomy-loader
**Date**: 2025-12-21

## Overview

Research findings for implementing XBRL taxonomy parsing in Ruby. All major decisions were resolved during the brainstorming phase (see `docs/plans/2025-12-21-taxonomy-loader-design.md`).

---

## 1. XML Parsing Library

**Decision**: Nokogiri

**Rationale**:
- De facto standard for XML parsing in Ruby
- Libxml2 backend provides excellent performance
- XPath support for navigating XBRL linkbase structures
- Already widely used in Ruby ecosystem (Rails, etc.)
- Handles malformed XML gracefully with clear error messages

**Alternatives Considered**:
| Library | Pros | Cons |
|---------|------|------|
| REXML | Pure Ruby, no native deps | 10-50x slower than Nokogiri |
| Ox | Fastest pure parsing | Less XPath support, smaller community |
| Oga | Pure Ruby, decent speed | Less mature, fewer features |

**Implementation Notes**:
- Use `Nokogiri::XML::Document` for parsing
- Use XPath for element selection (e.g., `//element[@name='a1101']`)
- Handle namespaces explicitly for XBRL elements

---

## 2. XULE Parsing Approach

**Decision**: Custom regex-based parser for gate rules only

**Rationale**:
- XULE is a domain-specific language without existing Ruby parsers
- Full XULE parsing is complex; we only need gate dependencies
- Gate rules follow a consistent pattern: `if $a1 = 'value' exists({@concept.local-name = 'fieldId'})`
- Regex extraction is sufficient for this subset

**Alternatives Considered**:
| Approach | Pros | Cons |
|----------|------|------|
| Full parser (Parslet/Treetop) | Complete XULE support | Overkill for gate rules only |
| Line-by-line regex | Simple, fast | Only handles known patterns |
| Shell out to Arelle | Authoritative parsing | External dependency, slow |

**Implementation Notes**:
- Pattern to match: `output {field1}-{field2}` followed by conditional logic
- Extract: controlling field, controlled field, required value
- Build dependency hash: `{ controlled_field: { controlling_field: value } }`

---

## 3. XBRL Type Mapping

**Decision**: Map to Ruby-friendly symbols, preserve original type

**Rationale**:
- Consumers need Ruby types for form rendering and validation
- XBRL generator needs original types for correct XML output
- Dual storage is minimal overhead

**Type Mapping Table**:
| XBRL Type | Ruby Symbol | Notes |
|-----------|-------------|-------|
| `xbrli:integerItemType` | `:integer` | Whole numbers |
| `xbrli:monetaryItemType` | `:monetary` | Currency amounts |
| `xbrli:stringItemType` | `:string` | Free text |
| `xbrli:booleanItemType` | `:boolean` | True/false |
| Enumeration with Oui/Non | `:boolean` | French yes/no |
| Other enumerations | `:enum` | Constrained values |

---

## 4. HTML Stripping from Labels

**Decision**: Use Nokogiri's text extraction

**Rationale**:
- XBRL labels contain HTML markup (`<p>`, `<b>`, `<ul>`, etc.)
- Plain text needed for form labels and API responses
- Nokogiri can parse HTML fragments and extract text content

**Implementation**:
```ruby
def strip_html(html_string)
  Nokogiri::HTML.fragment(html_string).text.strip
end
```

**Edge Cases**:
- Preserve meaningful whitespace between elements
- Handle `&lt;` and other HTML entities
- Return empty string for nil input

---

## 5. Caching Strategy

**Decision**: In-memory hash cache keyed by [industry, year]

**Rationale**:
- Questionnaires are immutable once loaded
- Memory usage is acceptable (~1-2MB per questionnaire)
- No need for external cache (Redis, etc.) for this use case
- Thread-safe with Ruby's GIL for reads

**Implementation**:
```ruby
def questionnaire_cache
  @questionnaire_cache ||= {}
end

def questionnaire(industry:, year:)
  questionnaire_cache[[industry, year]] ||= load_questionnaire(industry, year)
end
```

---

## 6. Error Handling Strategy

**Decision**: Fail fast with specific exceptions

**Rationale**:
- Taxonomy errors indicate configuration problems, not runtime issues
- Clear error messages help developers fix issues quickly
- Different exception types allow targeted rescue

**Exception Hierarchy**:
```
AmsfSurvey::Error
└── AmsfSurvey::TaxonomyLoadError
    ├── AmsfSurvey::MissingTaxonomyFileError
    ├── AmsfSurvey::MalformedTaxonomyError
    └── AmsfSurvey::MissingSemanticMappingError
```

---

## 7. Synthetic Test Fixtures

**Decision**: Create minimal but complete test taxonomy

**Rationale**:
- Core gem must not depend on real industry taxonomies (constitution)
- Synthetic fixtures are faster to parse and easier to maintain
- Can design fixtures to cover edge cases explicitly

**Fixture Structure**:
```
spec/fixtures/taxonomies/test_industry/2025/
├── test_survey.xsd          # 5-10 fields covering all types
├── test_survey_lab.xml      # Labels for each field
├── test_survey_pre.xml      # 2 sections with ordering
├── test_survey.xule         # 2-3 gate dependency rules
└── semantic_mappings.yml    # Subset of fields mapped
```

**Test Scenarios Covered**:
- Integer, boolean, string, monetary, enum types
- Standard and verbose labels
- Gate question with dependent fields
- Nested gate dependencies (A → B → C)
- Field without semantic mapping (uses XBRL code)
- Field without label (uses ID as fallback)

---

## 8. Dependencies to Add

**Gemspec Changes**:
```ruby
# amsf_survey.gemspec
spec.add_dependency "nokogiri", "~> 1.15"
```

**No additional development dependencies** - RSpec and SimpleCov already configured.

---

## Summary

All research items resolved. No blockers for Phase 1 design.

| Item | Decision | Confidence |
|------|----------|------------|
| XML Parsing | Nokogiri | High |
| XULE Parsing | Custom regex | Medium (may need refinement) |
| Type Mapping | Dual storage | High |
| HTML Stripping | Nokogiri fragment | High |
| Caching | In-memory hash | High |
| Error Handling | Fail fast + hierarchy | High |
| Test Fixtures | Synthetic minimal | High |
