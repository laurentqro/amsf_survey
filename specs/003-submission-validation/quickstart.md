# Quickstart: Submission & Validation

**Feature**: 003-submission-validation
**Date**: 2025-12-22

---

## Overview

This feature adds the `Submission` class for holding survey data and the `Validator` for checking data quality. After implementation, consumers can create submissions, track progress, and validate before generating XBRL.

---

## Basic Usage

### Creating a Submission

```ruby
require "amsf_survey"
require "amsf_survey/real_estate"  # Loads the industry plugin

# Create a new submission
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "ENTITY_001",
  period: Date.new(2025, 12, 31)
)

# Access the questionnaire
submission.questionnaire.sections  # => [Section, Section, ...]
submission.questionnaire.field_count  # => 150
```

### Setting Field Values

```ruby
# Set values using bracket notation
submission[:total_unique_clients] = 50
submission[:national_individuals] = 30
submission[:foreign_residents] = 20

# Type casting is automatic
submission[:transaction_count] = "100"  # Stored as Integer 100
submission[:total_amount] = "1234.56"   # Stored as BigDecimal

# Gate questions control visibility
submission[:acted_as_professional_agent] = "Oui"
```

### Reading Field Values

```ruby
# Get a value
value = submission[:total_unique_clients]  # => 50

# Access raw data hash
submission.data  # => { total_unique_clients: 50, ... }
```

---

## Tracking Completeness

### Check if Complete

```ruby
# Is the submission ready?
submission.complete?  # => false (some fields missing)

# What's missing?
submission.missing_fields  # => [:field_a, :field_b, ...]

# Progress percentage
submission.completion_percentage  # => 75.5
```

### Entry-Only Fields

```ruby
# Fields that require manual input (not prefillable)
submission.missing_entry_only_fields  # => [:training_hours, :policy_updates]
```

### Gate-Aware Completeness

```ruby
# Hidden fields are not counted as missing
submission[:acted_as_professional_agent] = "Non"

# Now dependent rental fields are hidden
submission.missing_fields  # => does NOT include rental-related fields
```

---

## Validation

### Basic Validation

```ruby
result = AmsfSurvey.validate(submission)

# Check overall status
result.valid?    # => true/false
result.complete? # => true/false

# Get errors and warnings
result.errors    # => [ValidationError, ...]
result.warnings  # => [ValidationError, ...]
```

### Working with Errors

```ruby
result.errors.each do |error|
  puts "Field: #{error.field}"
  puts "Rule: #{error.rule}"        # :presence, :range, :enum, :conditional
  puts "Message: #{error.message}"
  puts "Severity: #{error.severity}" # :error or :warning

  # Rule-specific context
  if error.rule == :range
    puts "Value: #{error.context[:value]}"
    puts "Max: #{error.context[:max]}"
  end
end
```

### Validation Example Output

```ruby
# Example with errors
result = AmsfSurvey.validate(submission)

result.errors.first
# => #<ValidationError
#      field: :total_unique_clients,
#      rule: :presence,
#      message: "Field 'Total Unique Clients' is required",
#      severity: :error,
#      context: {}>

result.errors[1]
# => #<ValidationError
#      field: :percentage_high_risk,
#      rule: :range,
#      message: "Field 'High Risk Percentage' must be at most 100",
#      severity: :error,
#      context: { value: 150, min: 0, max: 100 }>
```

---

## Error Handling

### Unknown Field

```ruby
# Raises immediately on unknown field
submission[:nonexistent_field] = 100
# => UnknownFieldError: Unknown field: nonexistent_field
```

### Unregistered Industry

```ruby
AmsfSurvey.build_submission(industry: :unknown, year: 2025, ...)
# => TaxonomyLoadError: Industry not registered: unknown
```

### Unsupported Year

```ruby
AmsfSurvey.build_submission(industry: :real_estate, year: 1999, ...)
# => TaxonomyLoadError: Year not supported for real_estate: 1999
```

---

## Integration with Forms

### Rails Controller Example

```ruby
class SubmissionsController < ApplicationController
  def new
    @submission = AmsfSurvey.build_submission(
      industry: :real_estate,
      year: 2025,
      entity_id: current_entity.id,
      period: Date.current.end_of_year
    )
    @questionnaire = @submission.questionnaire
  end

  def create
    @submission = AmsfSurvey.build_submission(
      industry: :real_estate,
      year: 2025,
      entity_id: current_entity.id,
      period: submission_params[:period]
    )

    # Load all field values
    submission_params[:data].each do |field_id, value|
      @submission[field_id.to_sym] = value
    end

    result = AmsfSurvey.validate(@submission)

    if result.valid?
      # Generate XBRL and submit (Phase 4)
      redirect_to success_path
    else
      @errors = result.errors
      render :new
    end
  end
end
```

### Form Helper

```ruby
# In view
<% @questionnaire.sections.each do |section| %>
  <fieldset>
    <legend><%= section.name %></legend>

    <% section.fields.each do |field| %>
      <% if field.visible?(@submission.data) %>
        <div class="field">
          <label><%= field.label %></label>
          <%= render_field_input(field, @submission[field.id]) %>
          <% if @errors.any? { |e| e.field == field.id } %>
            <span class="error">
              <%= @errors.find { |e| e.field == field.id }.message %>
            </span>
          <% end %>
        </div>
      <% end %>
    <% end %>
  </fieldset>
<% end %>
```

---

## Next Steps

After this feature is complete:

1. **Phase 4: XBRL Generation** - Convert validated submission to XBRL XML
2. **Phase 5: Arelle Integration** - Optional external validation
3. **Computed Fields** - Automatic formula evaluation

---

## API Reference

### Submission

| Method | Returns | Description |
|--------|---------|-------------|
| `[field_id]` | Any | Get field value |
| `[field_id]=value` | Any | Set field value (with type cast) |
| `questionnaire` | Questionnaire | Associated questionnaire |
| `data` | Hash | Raw data hash |
| `complete?` | Boolean | All required visible fields filled |
| `completion_percentage` | Float | Progress 0.0-100.0 |
| `missing_fields` | Array<Symbol> | Required unfilled field IDs |
| `missing_entry_only_fields` | Array<Symbol> | Manual-input fields only |

### ValidationResult

| Method | Returns | Description |
|--------|---------|-------------|
| `valid?` | Boolean | No errors |
| `complete?` | Boolean | No missing required fields |
| `errors` | Array<ValidationError> | Blocking issues |
| `warnings` | Array<ValidationError> | Non-blocking issues |
| `error_count` | Integer | Number of errors |
| `warning_count` | Integer | Number of warnings |

### ValidationError

| Attribute | Type | Description |
|-----------|------|-------------|
| `field` | Symbol | Field ID |
| `rule` | Symbol | Rule type |
| `message` | String | Human-readable message |
| `severity` | Symbol | `:error` or `:warning` |
| `context` | Hash | Rule-specific data |
