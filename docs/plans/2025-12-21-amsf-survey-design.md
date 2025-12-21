# AMSF Survey Gem Design

**Date:** 2025-12-21
**Status:** Validated
**Goal:** Ruby gem for Monaco AML/CFT regulatory survey submissions with XBRL generation and validation

---

## Overview

A Ruby gem architecture for Monaco AMSF (Autorité Monégasque de Supervision Financière) regulatory reporting. The gem provides:

- Questionnaire structure as single source of truth
- Local validation without network dependency
- XBRL instance generation for Strix portal submission
- Industry-agnostic core with pluggable industry taxonomies

### Design Principles

1. **Consumer-agnostic**: No knowledge of CRM, CLI, or any specific consumer
2. **Industry-agnostic core**: Core gem has zero knowledge of real estate, yachting, etc.
3. **Semantic abstraction**: Consumers have no notion of XBRL
4. **Form-driven structure**: Mirrors AMSF form layout for preview/adjustment workflows
5. **Lean scope**: No serialization (belongs in API layer)

---

## Section 1: Gem Structure & Naming

### Monorepo Layout

```
amsf_survey/                           # Monorepo root
├── amsf_survey/                       # Core gem
│   ├── lib/
│   │   └── amsf_survey/
│   │       ├── questionnaire.rb
│   │       ├── section.rb
│   │       ├── field.rb
│   │       ├── submission.rb
│   │       ├── validator.rb
│   │       ├── generator.rb
│   │       ├── registry.rb
│   │       └── taxonomy/
│   │           ├── loader.rb
│   │           └── xule_parser.rb
│   ├── spec/
│   ├── amsf_survey.gemspec
│   └── Gemfile
│
├── amsf_survey-real_estate/           # Industry plugin
│   ├── lib/
│   │   └── amsf_survey/
│   │       └── real_estate.rb         # ~10 lines, registers plugin
│   ├── taxonomies/
│   │   └── 2025/
│   │       ├── strix_*.xsd
│   │       ├── strix_*_lab.xml
│   │       ├── strix_*_def.xml
│   │       ├── strix_*_pre.xml
│   │       ├── strix_*_cal.xml
│   │       ├── strix_*.xule
│   │       └── semantic_mappings.yml
│   ├── spec/
│   ├── amsf_survey-real_estate.gemspec
│   └── README.md
│
└── README.md
```

### Naming Convention

- Core gem: `amsf_survey`
- Industry plugins: `amsf_survey-{industry}` (e.g., `amsf_survey-real_estate`, `amsf_survey-yachting`)

---

## Section 2: Core Gem Public API

### Registry

```ruby
AmsfSurvey.registered_industries       # => [:real_estate, :yachting, ...]
AmsfSurvey.registered?(industry)       # => true/false
AmsfSurvey.supported_years(industry)   # => [2024, 2025]
```

### Questionnaire Access

```ruby
questionnaire = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

questionnaire.industry          # => :real_estate
questionnaire.year              # => 2025
questionnaire.sections          # => [Section, Section, ...]
questionnaire.fields            # => [Field, Field, ...]
questionnaire.field(:field_id)  # => Field or nil

# Query by source type
questionnaire.computed_fields       # => fields derived from other fields
questionnaire.prefillable_fields    # => fields accepting external data
questionnaire.entry_only_fields     # => fields requiring fresh input
```

### Field Metadata

```ruby
field = questionnaire.field(:some_field)

# Identity
field.id                    # => :some_field
field.section               # => :section_name

# Type & Input
field.type                  # => :integer | :boolean | :string | :monetary | :enum
field.input_type            # => :number | :radio | :select | :text | :checkbox
field.valid_values          # => [true, false] or enum values or nil
field.value_labels          # => { true: "Oui", false: "Non" } or nil
field.unit                  # => :eur | :percent | nil

# Labels
field.label                 # => French label
field.label(:verbose)       # => Extended explanation
field.help_text             # => Guidance text or nil
field.input_guidance        # => Input instructions or nil

# Requirements
field.required?             # => true/false
field.source_type           # => :computed | :prefillable | :entry_only
field.computed?             # => true if source_type == :computed
field.prefillable?          # => true if source_type == :prefillable
field.entry_only?           # => true if source_type == :entry_only

# Overrides (for computed fields)
field.overridable?          # => true/false
field.override_reason_required?  # => true/false

# Conditional logic (gate questions)
field.gate?                 # => true if this controls other fields
field.depends_on            # => { other_field: value } or nil
field.dependent_fields      # => [:field_a, :field_b, ...] or []
field.visible?(data)        # => true/false based on gate answers

# Type casting
field.cast(value)           # => Casts string to appropriate type
```

### Submission Building

```ruby
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "ENTITY_001",
  period: Date.new(2025, 12, 31),
  data: { field_a: 50, field_b: 30, ... }
)
```

### Validation

```ruby
# Ruby-native validation (default)
result = AmsfSurvey.validate(submission)

# Optional Arelle validation for final compliance check
result = AmsfSurvey.validate(submission, engine: :arelle)

result.valid?               # => true/false
result.complete?            # => true/false (all required fields present)
result.errors               # => [{ field:, rule:, message:, ... }, ...]
result.warnings             # => [{ field:, rule:, message:, ... }, ...]
```

### XBRL Generation

```ruby
xml = AmsfSurvey.to_xbrl(submission)  # => String (XBRL instance XML)
```

---

## Section 3: Industry Plugin API

### Plugin Registration

Plugins contain only taxonomy files and minimal registration code:

```ruby
# lib/amsf_survey/real_estate.rb
require "amsf_survey"

AmsfSurvey.register_plugin(
  industry: :real_estate,
  taxonomy_path: File.expand_path("../../taxonomies", __dir__)
)
```

### Taxonomy Directory Structure

```
taxonomies/
└── 2025/
    ├── strix_Real_Estate_AML_CFT_survey_2025.xsd
    ├── strix_Real_Estate_AML_CFT_survey_2025_lab.xml
    ├── strix_Real_Estate_AML_CFT_survey_2025_def.xml
    ├── strix_Real_Estate_AML_CFT_survey_2025_pre.xml
    ├── strix_Real_Estate_AML_CFT_survey_2025_cal.xml
    ├── strix_Real_Estate_AML_CFT_survey_2025.xule
    └── semantic_mappings.yml
```

### Semantic Mappings

Maps XBRL codes to semantic field names:

```yaml
# taxonomies/2025/semantic_mappings.yml
version: 2025

fields:
  acted_as_professional_agent:
    xbrl_code: aACTIVE
    source_type: entry_only
    type: boolean
    gate: true

  total_unique_clients:
    xbrl_code: a1101
    source_type: computed
    type: integer
    formula: "national_individuals + foreign_residents + entity_clients"

  national_individuals:
    xbrl_code: a1102
    source_type: prefillable
    type: integer

  training_hours_provided:
    xbrl_code: a2501
    source_type: entry_only
    type: integer
    help_text: "Total training hours provided to all staff"
    input_guidance: "Include AML/CFT training and external courses"

sections:
  activity: Link_NoCountryDimension
  clients: Link_NoCountryDimension
```

---

## Section 4: Validation Engine

### Hybrid Approach

1. **Ruby-native validation** (default): Real-time, fast, no external dependencies
2. **Arelle validation** (optional): Final compliance check using official XULE rules

### Validation Categories

| Category | Description | Example |
|----------|-------------|---------|
| Presence | Required fields must be present | `total_clients` is required |
| Sum checks | Totals must equal component sums | `total = a + b + c` |
| Conditional presence | Fields required based on gates | If `acted_for_rentals`, rental fields required |
| Range validation | Values within acceptable bounds | Percentages 0-100 |
| Consistency | Cross-field logical consistency | Country breakdown sums match total |

### ValidationResult

```ruby
result = AmsfSurvey.validate(submission)

result.valid?               # => true if no errors
result.complete?            # => true if all required fields present
result.errors               # => Array of error hashes
result.warnings             # => Array of warning hashes

# Error structure
{
  field: :total_unique_clients,
  rule: :sum_check,
  message: "Total must equal sum of components",
  severity: :error,
  expected: 50,
  actual: 48
}
```

---

## Section 5: XBRL Instance Generation

### Output Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xbrli:xbrl
  xmlns:xbrli="http://www.xbrl.org/2003/instance"
  xmlns:strix="http://www.strix.mc/taxonomy/real-estate/2025">

  <!-- Contexts -->
  <xbrli:context id="ctx_2025">
    <xbrli:entity>
      <xbrli:identifier scheme="http://strix.mc">ENTITY_001</xbrli:identifier>
    </xbrli:entity>
    <xbrli:period>
      <xbrli:instant>2025-12-31</xbrli:instant>
    </xbrli:period>
  </xbrli:context>

  <!-- Facts -->
  <strix:a1101 contextRef="ctx_2025" decimals="0">50</strix:a1101>
  <strix:a1102 contextRef="ctx_2025" decimals="0">30</strix:a1102>

</xbrli:xbrl>
```

### Generator API

```ruby
xml = AmsfSurvey.to_xbrl(submission)

# With options
xml = AmsfSurvey.to_xbrl(submission, pretty: true)
xml = AmsfSurvey.to_xbrl(submission, include_empty: false)
```

---

## Section 6: Integration Patterns

### Form Rendering Support

Fields provide metadata for form generation:

```ruby
field.input_type      # => :number | :radio | :select | :text | :checkbox
field.valid_values    # => Enum values or boolean options
field.value_labels    # => Human-readable labels for values
field.help_text       # => Field description
field.input_guidance  # => How to fill the field
```

### Input Type Mapping

| Field Type | Input Type | Rendered As |
|------------|------------|-------------|
| `:boolean` | `:radio` | Radio buttons (Oui/Non) |
| `:integer` | `:number` | Number input |
| `:monetary` | `:number` | Number input with currency |
| `:string` | `:text` | Text input or textarea |
| `:enum` | `:select` | Dropdown select |

### Gate Question Handling

```ruby
# Check if field should be visible
field.visible?(submission.data)  # => true/false

# Get dependent fields
gate_field.dependent_fields  # => [:field_a, :field_b, ...]
```

---

## Section 7: Submission Object with ActiveModel

### ActiveModel Integration

```ruby
module AmsfSurvey
  class Submission
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations

    attribute :entity_id, :string
    attribute :period, :date
    attribute :industry, :string
    attribute :year, :integer

    validates :entity_id, :industry, :year, :period, presence: true
    validate :industry_supported
    validate :year_supported
    validate :questionnaire_rules

    attr_reader :data

    def initialize(attributes = {})
      @data = {}
      super(attributes.except(:data))
      load_data(attributes[:data]) if attributes[:data]
    end

    def [](field_id)
      @data[field_id]
    end

    def []=(field_id, value)
      field = questionnaire.field(field_id)
      raise UnknownFieldError, field_id unless field
      @data[field_id] = field.cast(value)
    end

    def questionnaire
      @questionnaire ||= AmsfSurvey.questionnaire(industry: industry.to_sym, year: year)
    end

    def complete?
      missing_fields.empty?
    end

    def completion_percentage
      total = questionnaire.fields.count { |f| f.required? }
      filled = total - missing_fields.count
      (filled.to_f / total * 100).round(1)
    end

    def missing_fields
      questionnaire.fields.select do |field|
        field.required? && field.visible?(data) && @data[field.id].nil?
      end.map(&:id)
    end

    def missing_entry_only_fields
      missing_fields.select { |id| questionnaire.field(id).entry_only? }
    end

    def validation_result
      @validation_result ||= AmsfSurvey::Validator.validate(self)
    end

    def persisted?
      false
    end
  end
end
```

---

## Section 8: Test Strategy

### Test Structure

```
amsf_survey/
├── spec/
│   ├── spec_helper.rb
│   ├── amsf_survey_spec.rb
│   │
│   ├── questionnaire/
│   │   ├── questionnaire_spec.rb
│   │   ├── section_spec.rb
│   │   └── field_spec.rb
│   │
│   ├── submission/
│   │   ├── submission_spec.rb
│   │   ├── data_access_spec.rb
│   │   └── validations_spec.rb
│   │
│   ├── validator/
│   │   ├── ruby_validator_spec.rb
│   │   ├── arelle_validator_spec.rb
│   │   └── validation_result_spec.rb
│   │
│   ├── generator/
│   │   ├── xbrl_generator_spec.rb
│   │   ├── context_builder_spec.rb
│   │   └── fact_builder_spec.rb
│   │
│   ├── taxonomy/
│   │   ├── loader_spec.rb
│   │   ├── registry_spec.rb
│   │   └── xule_parser_spec.rb
│   │
│   ├── integration/
│   │   └── full_submission_spec.rb
│   │
│   └── fixtures/
│       └── taxonomies/
│           └── test_industry/    # Synthetic, not real estate
│               └── 2025/
│
amsf_survey-real_estate/
├── spec/
│   ├── registration_spec.rb
│   ├── taxonomy_files_spec.rb
│   └── semantic_mappings_spec.rb
```

### Coverage Targets

| Component | Target | Notes |
|-----------|--------|-------|
| All classes | 100% | Line and branch coverage |
| Validation rules | 100% | Every XULE rule translated |
| Type casting | 100% | All type/value combinations |

### Test Fixtures

Core gem uses synthetic taxonomy (no industry knowledge):

```yaml
# spec/fixtures/taxonomies/test_industry/2025/semantic_mappings.yml
fields:
  field_a:
    xbrl_code: test001
    source_type: prefillable
    type: integer

  field_b:
    xbrl_code: test002
    source_type: prefillable
    type: integer

  field_total:
    xbrl_code: test003
    source_type: computed
    formula: "field_a + field_b"
```

---

## Section 9: Field Source Types

### Source Type Definitions

| Source Type | Description | Example |
|-------------|-------------|---------|
| `:computed` | Derived from other survey fields | `total = a + b + c` |
| `:prefillable` | Can be pre-populated from external data | Transaction counts |
| `:entry_only` | Requires fresh input each submission | Training hours, policy updates |

### Field Methods

```ruby
field.source_type       # => :computed | :prefillable | :entry_only
field.computed?         # => true if source_type == :computed
field.prefillable?      # => true if source_type == :prefillable
field.entry_only?       # => true if source_type == :entry_only
```

### Submission Queries

```ruby
submission.missing_fields              # All unfilled required fields
submission.missing_entry_only_fields   # Fields with no external source
submission.complete?                   # true when all required fields filled
submission.completion_percentage       # Progress indicator
```

---

## Design Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Serialization | Not in gem | Presentation concern belongs in API layer |
| Multi-industry | Core + plugins | Clean separation, independent releases |
| Validation | Hybrid (Ruby + Arelle) | Fast local + authoritative compliance |
| Multi-year | Single year now, ready for multi | Conservative, avoids premature complexity |
| Field source types | 3 types (computed/prefillable/entry_only) | Consumer-agnostic, no "CRM" or "hybrid" |
| Gate questions | Derived from XULE | Single source of truth, no manual YAML |

---

## Next Steps

1. Set up monorepo structure
2. Implement core gem skeleton
3. Implement taxonomy loader
4. Implement questionnaire/field models
5. Implement submission with ActiveModel
6. Implement Ruby validator
7. Implement XBRL generator
8. Create real_estate plugin with taxonomy files
9. Write comprehensive test suite
10. Optional: Arelle integration
