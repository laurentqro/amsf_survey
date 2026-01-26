# Migration Guide: immo_crm → amsf_survey gem

This guide explains how to replace the ad-hoc XBRL code in `immo_crm` with the `amsf_survey` gem.

## Overview

### What You Have Now (immo_crm)

```
immo_crm/
├── app/models/xbrl/
│   ├── taxonomy.rb              # Parses .xsd, _lab.xml, _pre.xml
│   ├── taxonomy_element.rb      # Field metadata value object
│   ├── survey.rb                # 600+ field definitions, sections
│   ├── element_definitions.rb   # Computation registry (40+ formulas)
│   └── element_manifest.rb      # Combines taxonomy + stored values
├── app/services/
│   ├── submission_builder.rb    # Orchestrates submission creation
│   ├── submission_renderer.rb   # XBRL/HTML/Markdown output
│   ├── calculation_engine.rb    # CRM → XBRL value calculation
│   └── validation_service.rb    # External Arelle validation
├── app/models/
│   ├── submission.rb            # Submission lifecycle
│   └── submission_value.rb      # Stored values with sources
├── app/views/submissions/
│   └── show.xml.erb             # XBRL template
├── docs/taxonomy/               # AMSF taxonomy files
└── config/initializers/
    └── xbrl_taxonomy.rb         # Boot-time loading
```

### What the Gem Provides

```ruby
# The gem handles:
AmsfSurvey.questionnaire(...)    # ← Replaces Xbrl::Taxonomy + Xbrl::Survey
AmsfSurvey.build_submission(...) # ← Replaces SubmissionBuilder (partial)
AmsfSurvey.validate(...)         # ← Replaces ValidationService (Ruby-native)
AmsfSurvey.to_xbrl(...)          # ← Replaces SubmissionRenderer.to_xbrl + ERB template
```

---

## Step-by-Step Migration

### Step 1: Add the Gems

```ruby
# Gemfile
gem 'amsf_survey', path: '../amsf_survey/amsf_survey'
gem 'amsf_survey-real_estate', path: '../amsf_survey/amsf_survey-real_estate'
```

Or once published:
```ruby
gem 'amsf_survey'
gem 'amsf_survey-real_estate'
```

```bash
bundle install
```

### Step 2: Remove Taxonomy Files

Delete these from immo_crm (the gem has them):

```bash
rm -rf docs/taxonomy/
rm config/xbrl_short_labels.yml
```

### Step 3: Create an Initializer

```ruby
# config/initializers/amsf_survey.rb
require 'amsf_survey/real_estate'

# Verify the gem loaded correctly
Rails.application.config.after_initialize do
  q = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)
  Rails.logger.info "AMSF Survey loaded: #{q.fields.count} fields"
end
```

### Step 4: Delete Old Taxonomy Code

These files are fully replaced by the gem:

```bash
rm app/models/xbrl/taxonomy.rb
rm app/models/xbrl/taxonomy_element.rb
rm app/models/xbrl/survey.rb
rm config/initializers/xbrl_taxonomy.rb
```

### Step 5: Update ElementDefinitions (Keep It!)

`Xbrl::ElementDefinitions` contains your CRM-specific computation logic. The gem doesn't replace this - it's your business logic.

**Keep:** `app/models/xbrl/element_definitions.rb`

But update it to use gem field names:

```ruby
# Before (using XBRL codes directly)
DEFINITIONS = {
  "a1101" => Definition.new(
    element_name: "a1101",
    description: "Total unique clients",
    compute: ->(ctx) { ctx.clients.distinct.count }
  ),
  # ...
}

# After (can use semantic names, map to XBRL at output)
DEFINITIONS = {
  total_clients: Definition.new(
    element_name: :total_clients,  # Semantic name
    xbrl_code: "a1101",            # Keep for reference
    description: "Total unique clients",
    compute: ->(ctx) { ctx.clients.distinct.count }
  ),
  # ...
}
```

### Step 6: Refactor ElementManifest

Replace the custom manifest with gem integration:

```ruby
# app/models/xbrl/element_manifest.rb (simplified)
module Xbrl
  class ElementManifest
    def initialize(submission)
      @submission = submission
      @questionnaire = AmsfSurvey.questionnaire(
        industry: :real_estate,
        year: submission.year
      )
    end

    def field(name)
      @questionnaire.field(name)
    end

    def all_fields
      @questionnaire.fields
    end

    def fields_by_section
      @questionnaire.sections.each_with_object({}) do |section, hash|
        hash[section.id] = section.fields
      end
    end

    def value_for(field_id)
      @submission.submission_values.find_by(element_name: field_id.to_s)&.value
    end
  end
end
```

### Step 7: Refactor SubmissionBuilder

The gem's `Submission` is a value object, not a persisted model. Your `SubmissionBuilder` bridges the gap:

```ruby
# app/services/submission_builder.rb
class SubmissionBuilder
  def initialize(organization:, year:)
    @organization = organization
    @year = year
    @questionnaire = AmsfSurvey.questionnaire(industry: :real_estate, year: year)
  end

  def build
    # 1. Find or create the ActiveRecord submission
    submission = Submission.find_or_create_by!(
      organization: @organization,
      year: @year
    )

    # 2. Calculate values from CRM
    calculated_data = CalculationEngine.new(@organization, @year).calculate_all

    # 3. Load settings-based values
    settings_data = load_settings_values

    # 4. Load manual overrides
    manual_data = load_manual_values(submission)

    # 5. Merge all data sources
    merged_data = calculated_data.merge(settings_data).merge(manual_data)

    # 6. Store in SubmissionValues (for audit trail)
    store_values(submission, merged_data)

    # 7. Build gem submission for validation/generation
    @gem_submission = AmsfSurvey.build_submission(
      industry: :real_estate,
      year: @year,
      entity_id: @organization.rci_number,
      period: Date.new(@year, 12, 31),
      data: merged_data
    )

    submission
  end

  def gem_submission
    @gem_submission
  end

  def validate
    AmsfSurvey.validate(@gem_submission)
  end

  def to_xbrl(pretty: false)
    AmsfSurvey.to_xbrl(@gem_submission, pretty: pretty)
  end

  private

  def load_settings_values
    setting = @organization.setting
    return {} unless setting

    # Map Setting attributes to semantic field names
    {
      has_aml_policy: setting.ctrl_aC1201 ? "Oui" : "Non",
      policy_board_approved: setting.ctrl_aC1202 ? "Oui" : "Non",
      # ... map all 105 control elements
    }
  end

  def load_manual_values(submission)
    submission.submission_values
      .where(source: 'manual')
      .each_with_object({}) do |sv, hash|
        hash[sv.element_name.to_sym] = sv.value
      end
  end

  def store_values(submission, data)
    data.each do |field_id, value|
      field = @questionnaire.field(field_id)
      next unless field

      submission.submission_values.find_or_initialize_by(
        element_name: field_id.to_s
      ).update!(
        value: value,
        source: determine_source(field_id)
      )
    end
  end

  def determine_source(field_id)
    # Your logic to determine if calculated, from_settings, or manual
  end
end
```

### Step 8: Refactor SubmissionRenderer

Replace the ERB template with gem generation:

```ruby
# app/services/submission_renderer.rb
class SubmissionRenderer
  def initialize(submission)
    @submission = submission
    @builder = SubmissionBuilder.new(
      organization: submission.organization,
      year: submission.year
    )
    @builder.build
  end

  def to_xbrl
    @builder.to_xbrl(pretty: true)
  end

  def to_html
    # Keep your HTML rendering logic
    render_html_review
  end

  def to_markdown
    # Keep your Markdown export logic
    render_markdown_export
  end
end
```

**Delete:** `app/views/submissions/show.xml.erb` (gem generates XBRL)

### Step 9: Update CalculationEngine

Keep your calculation logic, but use gem field names:

```ruby
# app/services/calculation_engine.rb
class CalculationEngine
  def initialize(organization, year)
    @organization = organization
    @year = year
    @questionnaire = AmsfSurvey.questionnaire(industry: :real_estate, year: year)
  end

  def calculate_all
    {
      # Client counts
      total_clients: calculate_total_clients,
      clients_nationals: calculate_national_clients,
      clients_foreign_residents: calculate_foreign_resident_clients,
      clients_non_residents: calculate_non_resident_clients,

      # Transaction stats
      transactions_by_clients: calculate_transactions,
      funds_transferred_by_clients: calculate_funds_transferred,

      # ... all your existing calculations, using semantic names
    }
  end

  private

  def calculate_total_clients
    clients_scope.distinct.count
  end

  def calculate_national_clients
    clients_scope.where(nationality: 'MC').distinct.count
  end

  # ... rest of your calculation methods
end
```

### Step 10: Update ValidationService

You can now use Ruby-native validation from the gem, with optional external Arelle:

```ruby
# app/services/validation_service.rb
class ValidationService
  def initialize(submission)
    @submission = submission
    @builder = SubmissionBuilder.new(
      organization: submission.organization,
      year: submission.year
    )
    @builder.build
  end

  def validate
    # Ruby-native validation (fast, no network)
    result = @builder.validate

    if result.valid?
      # Optionally call external Arelle for authoritative check
      if Rails.configuration.x.arelle_validation_enabled
        arelle_result = validate_with_arelle(@builder.to_xbrl)
        merge_results(result, arelle_result)
      end
    end

    result
  end

  private

  def validate_with_arelle(xbrl_content)
    # Your existing external validation logic
  end
end
```

### Step 11: Update Controllers

```ruby
# app/controllers/submissions_controller.rb
class SubmissionsController < ApplicationController
  def show
    @submission = Submission.find(params[:id])
    @builder = SubmissionBuilder.new(
      organization: @submission.organization,
      year: @submission.year
    )
    @builder.build

    # Access questionnaire through gem
    @questionnaire = AmsfSurvey.questionnaire(
      industry: :real_estate,
      year: @submission.year
    )
  end

  def download
    @submission = Submission.find(params[:id])
    renderer = SubmissionRenderer.new(@submission)

    send_data renderer.to_xbrl,
      filename: "submission_#{@submission.year}.xml",
      type: 'application/xml'
  end

  def validate
    @submission = Submission.find(params[:id])
    result = ValidationService.new(@submission).validate

    if result.valid?
      @submission.validate_submission!
      redirect_to @submission, notice: "Validation successful"
    else
      @errors = result.errors
      render :show, status: :unprocessable_entity
    end
  end
end
```

### Step 12: Update Views

```erb
<%# app/views/submissions/show.html.erb %>

<% @questionnaire.sections.each do |section| %>
  <h2><%= section.name %></h2>

  <% section.fields.each do |field| %>
    <% next unless field.visible?(@builder.gem_submission.data) %>

    <div class="field">
      <label><%= field.label %></label>

      <% value = @builder.gem_submission[field.id] %>
      <span class="value"><%= value %></span>

      <% if field.gate? %>
        <span class="badge">Controls other fields</span>
      <% end %>
    </div>
  <% end %>
<% end %>
```

---

## Mapping Reference

### Old → New Field Access

| Before (immo_crm) | After (gem) |
|-------------------|-------------|
| `Xbrl::Taxonomy.instance.find("a1101")` | `questionnaire.field(:total_clients)` or `questionnaire.field(:a1101)` |
| `element.label` | `field.label` |
| `element.type` | `field.type` |
| `element.dimensional?` | `field.dimensional?` (if supported) |
| `Xbrl::Survey::SECTIONS` | `questionnaire.sections` |
| `Xbrl::Survey.fields_for_section(section_id)` | `section.fields` |

### Old → New Services

| Before | After |
|--------|-------|
| `Xbrl::Taxonomy.instance` | `AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)` |
| `SubmissionRenderer.new(s).to_xbrl` | `AmsfSurvey.to_xbrl(submission)` |
| `ValidationService.new(s).validate` | `AmsfSurvey.validate(submission)` |

### Files to Delete

```bash
# Taxonomy parsing (gem does this)
rm app/models/xbrl/taxonomy.rb
rm app/models/xbrl/taxonomy_element.rb
rm app/models/xbrl/survey.rb
rm config/initializers/xbrl_taxonomy.rb

# XBRL template (gem generates)
rm app/views/submissions/show.xml.erb

# Taxonomy files (gem has them)
rm -rf docs/taxonomy/
rm config/xbrl_short_labels.yml
```

### Files to Keep & Refactor

```bash
# Your CRM-specific logic
app/models/xbrl/element_definitions.rb  # Computation formulas
app/models/xbrl/element_manifest.rb     # Simplified wrapper
app/services/calculation_engine.rb       # CRM → values
app/services/submission_builder.rb       # Orchestration
app/services/submission_renderer.rb      # Multi-format (keep HTML/MD)
app/services/validation_service.rb       # External Arelle (optional)

# ActiveRecord models
app/models/submission.rb                 # Lifecycle, persistence
app/models/submission_value.rb           # Value storage, audit
```

---

## Benefits After Migration

1. **No more taxonomy parsing code** - Gem handles .xsd, _lab.xml, _pre.xml, .xule
2. **Semantic field names** - Use `:total_clients` instead of `"a1101"`
3. **Gate logic built-in** - `field.visible?(data)` just works
4. **Validated XBRL output** - Gem generates correct namespaces, contexts, facts
5. **Ruby-native validation** - Fast validation without external service
6. **Multi-year support** - Easy to add 2026 taxonomy when AMSF releases it
7. **Testable** - 374 tests with 99.47% coverage in the gem

---

## Gotchas

### 1. Field Type Differences

The gem uses Ruby types:
- Boolean fields store `"Oui"` / `"Non"` (strings, not booleans)
- Monetary fields use `BigDecimal`
- The `TypeCaster` handles conversion

### 2. Dimensional Elements

The gem handles country breakdown fields (like `a1103`) but you may need to adapt how you store/retrieve the dimensional data.

### 3. Validation Locale

```ruby
# Default is French (Monaco context)
result = AmsfSurvey.validate(submission)

# English messages for development
result = AmsfSurvey.validate(submission, locale: :en)
```

### 4. Submission is a Value Object

The gem's `Submission` is not ActiveRecord. You keep your AR `Submission` model for persistence and use the gem's submission for generation/validation.

---

## Testing the Migration

```ruby
# test/integration/amsf_survey_migration_test.rb
require 'test_helper'

class AmsfSurveyMigrationTest < ActiveSupport::TestCase
  test "gem generates same XBRL as old code" do
    org = organizations(:acme_realty)
    year = 2025

    # Generate with old code (before removing)
    old_renderer = SubmissionRenderer.new(org.submissions.find_by(year: year))
    old_xbrl = old_renderer.to_xbrl

    # Generate with gem
    builder = SubmissionBuilder.new(organization: org, year: year)
    builder.build
    new_xbrl = builder.to_xbrl

    # Compare (normalize whitespace)
    assert_equal normalize_xml(old_xbrl), normalize_xml(new_xbrl)
  end

  test "gem validation matches old validation" do
    # Similar comparison test for validation results
  end

  private

  def normalize_xml(xml)
    Nokogiri::XML(xml).to_xml(indent: 0)
  end
end
```

---

## Timeline Estimate

| Phase | Tasks | Complexity |
|-------|-------|------------|
| 1. Setup | Add gems, create initializer | Low |
| 2. Remove taxonomy | Delete old parsing code | Low |
| 3. Refactor services | Update SubmissionBuilder, Renderer | Medium |
| 4. Update controllers | Use gem API | Low |
| 5. Update views | Use gem field access | Medium |
| 6. Testing | Verify XBRL output matches | Medium |
| 7. Cleanup | Remove dead code | Low |

---

## Questions?

If you hit issues during migration, check:
1. Field name mappings in `semantic_mappings.yml`
2. Type casting differences
3. Gate dependency behavior
4. Dimensional element handling
