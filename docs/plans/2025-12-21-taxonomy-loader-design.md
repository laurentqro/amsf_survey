# Taxonomy Loader Design

**Date:** 2025-12-21
**Status:** Validated
**Branch:** 002-taxonomy-loader

---

## Overview

The taxonomy loader parses XBRL files and builds Questionnaire, Section, and Field objects. It extracts field definitions, labels, presentation ordering, and gate dependencies from taxonomy files, merging with semantic mappings to create a clean Ruby API.

## Architecture

```
amsf_survey/lib/amsf_survey/
├── taxonomy/
│   ├── loader.rb              # Orchestrates parsing
│   ├── schema_parser.rb       # Parses .xsd for field definitions
│   ├── label_parser.rb        # Parses _lab.xml for French labels
│   ├── presentation_parser.rb # Parses _pre.xml for sections/ordering
│   └── xule_parser.rb         # Parses .xule for gate dependencies
├── questionnaire.rb           # Holds sections and fields
├── section.rb                 # Groups of fields from presentation links
└── field.rb                   # Individual field with all metadata
```

### Data Flow

1. `AmsfSurvey.questionnaire(industry:, year:)` called
2. Registry looks up taxonomy path for that industry
3. Loader orchestrates the four parsers
4. Parsers read files and return intermediate data structures
5. Loader merges everything with semantic_mappings.yml
6. Returns a cached Questionnaire object

---

## Parser Responsibilities

### SchemaParser (.xsd)

- Field IDs (e.g., `a1101`, `aACTIVE`)
- XBRL types (`xbrli:integerItemType`, `xbrli:monetaryItemType`)
- Enumerations (valid values like `["Oui", "Non"]`)
- Abstract vs concrete elements

### LabelParser (_lab.xml)

- Standard labels (French question text)
- Verbose labels (extended explanations)
- Maps labels to field IDs via xlink:href references

### PresentationParser (_pre.xml)

- Section groupings from presentationLink role URIs
- Field ordering within sections (from order attribute)
- Parent-child hierarchy for display nesting

### XuleParser (.xule)

- Gate dependencies: "if field X = value, then field Y is required"
- Identifies gate fields (fields that control visibility of others)
- Builds dependency map: `{ a1101: { aACTIVE: "Oui" } }`

---

## Data Models

### Field

```ruby
class Field
  attr_reader :id,            # :a1101 (XBRL code)
              :name,          # :total_unique_clients (semantic name)
              :type,          # :integer, :boolean, :string, :monetary, :enum
              :xbrl_type,     # "xbrli:integerItemType" (original)
              :source_type,   # :computed, :prefillable, :entry_only
              :label,         # French question text (HTML stripped)
              :verbose_label, # Extended explanation
              :valid_values,  # ["Oui", "Non"] or nil
              :section,       # :activity, :clients, etc.
              :order,         # Display order within section
              :depends_on,    # { aACTIVE: "Oui" } or nil
              :gate           # true if this field controls others

  def boolean?    = type == :boolean
  def required?   = !depends_on.nil? || source_type != :computed
  def visible?(data)
    return true unless depends_on
    depends_on.all? { |field_id, value| data[field_id] == value }
  end
end
```

### Section

```ruby
class Section
  attr_reader :id,     # :no_country_dimension
              :name,   # "Link_NoCountryDimension"
              :order,  # Position in questionnaire
              :fields  # Array of Field objects

  def visible?(data)
    fields.any? { |f| f.visible?(data) }
  end
end
```

### Questionnaire

```ruby
class Questionnaire
  attr_reader :industry,  # :real_estate
              :year,      # 2025
              :sections   # Array of Section objects

  def fields
    sections.flat_map(&:fields)
  end

  def field(id)
    fields.find { |f| f.name == id || f.id == id }
  end

  def gate_fields
    fields.select(&:gate)
  end

  def computed_fields
    fields.select { |f| f.source_type == :computed }
  end

  def prefillable_fields
    fields.select { |f| f.source_type == :prefillable }
  end

  def entry_only_fields
    fields.select { |f| f.source_type == :entry_only }
  end
end
```

---

## Loader and Caching

```ruby
module AmsfSurvey
  module Taxonomy
    class Loader
      def initialize(taxonomy_path, year)
        @path = File.join(taxonomy_path, year.to_s)
      end

      def load
        schema   = SchemaParser.new(xsd_file).parse
        labels   = LabelParser.new(lab_file).parse
        sections = PresentationParser.new(pre_file).parse
        gates    = XuleParser.new(xule_file).parse
        mappings = load_semantic_mappings

        build_questionnaire(schema, labels, sections, gates, mappings)
      end
    end
  end
end
```

Caching in Registry:

```ruby
def questionnaire(industry:, year:)
  cache_key = [industry, year]
  questionnaire_cache[cache_key] ||= load_questionnaire(industry, year)
end
```

---

## Semantic Mappings File

Located at `taxonomies/{year}/semantic_mappings.yml`:

```yaml
version: 2025

fields:
  aACTIVE:
    name: acted_as_professional_agent
    source_type: entry_only

  a1101:
    name: total_unique_clients
    source_type: computed

  a1102:
    name: national_individuals
    source_type: prefillable
```

Fields not in this file use XBRL code as name and default to `:entry_only`.

---

## Type Mapping

| XBRL Type | Ruby Type |
|-----------|-----------|
| xbrli:integerItemType | :integer |
| xbrli:monetaryItemType | :monetary |
| xbrli:stringItemType | :string |
| Oui/Non enumeration | :boolean |
| Other enumerations | :enum |

Both `type` (Ruby-friendly) and `xbrl_type` (original) are stored on Field.

---

## Error Handling

```ruby
class TaxonomyLoadError < Error; end
class MissingTaxonomyFileError < TaxonomyLoadError; end
class MalformedTaxonomyError < TaxonomyLoadError; end
class MissingSemanticMappingError < TaxonomyLoadError; end
```

| Situation | Behavior |
|-----------|----------|
| Missing XSD/XML file | Raise MissingTaxonomyFileError |
| Malformed XML | Raise MalformedTaxonomyError |
| Missing semantic_mappings.yml | Raise MissingSemanticMappingError |
| Field in mappings not in XSD | Log warning, skip |
| Field in XSD not in mappings | Use XBRL code, default source_type |

---

## Testing Strategy

Synthetic fixtures in `spec/fixtures/taxonomies/test_industry/2025/`:

- test_survey.xsd
- test_survey_lab.xml
- test_survey_pre.xml
- test_survey.xule
- semantic_mappings.yml

### Coverage

| Component | Tests |
|-----------|-------|
| SchemaParser | Field IDs, types, enumerations |
| LabelParser | Standard and verbose labels |
| PresentationParser | Sections, ordering, hierarchy |
| XuleParser | Gate dependencies |
| Loader | Merges all, applies mappings |
| Field | visible?, required?, type helpers |
| Questionnaire | field() lookup, filtering |
| Caching | Same instance on second call |

### Edge Cases

- Field with no label (uses ID as fallback)
- Field with no semantic mapping (uses XBRL code)
- Nested gate dependencies (A → B → C)
- Empty sections (filtered out)

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Field naming | semantic_mappings.yml | Cleaner API than XBRL codes |
| Mapping format | Minimal (name + source_type) | XBRL is source of truth |
| XULE scope | Gate questions only | Validation rules deferred |
| Sections | From presentation links | Matches XBRL structure |
| Type storage | Both type and xbrl_type | Need original for XBRL generation |
| Loading | Lazy with caching | No startup penalty |
