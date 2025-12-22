# Quickstart: Taxonomy Loader

**Feature**: 002-taxonomy-loader
**Date**: 2025-12-21

## Prerequisites

- Ruby 3.2+
- Core gem and plugin gem installed
- Taxonomy files present in plugin gem

## Installation

Add Nokogiri dependency to core gemspec:

```ruby
# amsf_survey/amsf_survey.gemspec
spec.add_dependency "nokogiri", "~> 1.15"
```

Run bundle install:

```bash
cd amsf_survey && bundle install
```

## Basic Usage

### Load a Questionnaire

```ruby
require "amsf_survey"
require "amsf_survey/real_estate"

# Load questionnaire for an industry and year
questionnaire = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

# Access basic info
questionnaire.industry    #=> :real_estate
questionnaire.year        #=> 2025
questionnaire.field_count #=> 487
```

### Navigate Sections

```ruby
# Get all sections in order
questionnaire.sections.each do |section|
  puts "#{section.name}: #{section.field_count} fields"
end

# Access a specific section's fields
section = questionnaire.sections.first
section.fields.each do |field|
  puts "  - #{field.name}: #{field.type}"
end
```

### Look Up Fields

```ruby
# By semantic name
field = questionnaire.field(:total_unique_clients)

# By XBRL code
field = questionnaire.field(:a1101)

# Access field metadata
field.name          #=> :total_unique_clients
field.id            #=> :a1101
field.type          #=> :integer
field.label         #=> "Veuillez indiquer le nombre total de clients..."
field.source_type   #=> :computed
```

### Filter Fields by Source Type

```ruby
# Fields that can be pre-populated from CRM data
questionnaire.prefillable_fields.each do |field|
  puts "#{field.name} can be prefilled"
end

# Fields that require fresh user input
questionnaire.entry_only_fields.each do |field|
  puts "#{field.name} needs user input"
end

# Fields computed from other fields
questionnaire.computed_fields.each do |field|
  puts "#{field.name} is calculated"
end
```

### Check Field Visibility (Gate Questions)

```ruby
# Simulate user answers
user_data = {
  aACTIVE: "Oui",
  aACTIVEPS: "Oui"
}

# Check if a field should be shown
field = questionnaire.field(:total_unique_clients)
field.visible?(user_data)  #=> true

# Check with "Non" answer
user_data[:aACTIVE] = "Non"
field.visible?(user_data)  #=> false

# Get all gate questions
questionnaire.gate_fields.each do |field|
  puts "#{field.name} controls other fields"
end
```

### Handle Boolean Fields

```ruby
field = questionnaire.field(:acted_as_professional_agent)

field.boolean?      #=> true
field.valid_values  #=> ["Oui", "Non"]
field.type          #=> :boolean
```

### Access Verbose Labels

```ruby
field = questionnaire.field(:total_unique_clients)

# Short label for form heading
field.label         #=> "Veuillez indiquer le nombre total de clients..."

# Extended explanation for help text
field.verbose_label #=> "L'expression « clients uniques » signifie que..."
```

## Caching Behavior

Questionnaires are cached after first load:

```ruby
# First call parses files (~1-2 seconds)
q1 = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

# Second call returns cached instance (< 1ms)
q2 = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

q1.object_id == q2.object_id  #=> true
```

## Error Handling

```ruby
begin
  questionnaire = AmsfSurvey.questionnaire(industry: :unknown, year: 2025)
rescue AmsfSurvey::TaxonomyLoadError => e
  puts "Failed to load taxonomy: #{e.message}"
end

# Specific error types
rescue AmsfSurvey::MissingTaxonomyFileError
  # Taxonomy file not found
rescue AmsfSurvey::MalformedTaxonomyError
  # XML parsing failed
rescue AmsfSurvey::MissingSemanticMappingError
  # semantic_mappings.yml not found
```

## Creating Semantic Mappings

Create `taxonomies/{year}/semantic_mappings.yml` in your plugin:

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

Fields not in this file will:
- Use XBRL code as `name` (e.g., `:a1103`)
- Default to `source_type: :entry_only`

## Running Tests

```bash
cd amsf_survey
bundle exec rspec

# Expected output
# 100% line coverage
# 100% branch coverage
```
