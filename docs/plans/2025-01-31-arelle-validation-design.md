# Arelle Validation Integration Design

## Overview

Add Arelle-driven validation tests to amsf_survey-real_estate plugin gem. Tests generate XBRL and validate against a running arelle_api instance, enabling validation-driven development.

## Architecture

```
amsf_survey/              ← Core gem: XBRL generation, no industry knowledge
amsf_survey-real_estate/  ← Plugin: taxonomy + Arelle validation tests
arelle_api/               ← Python service: validates XBRL via Arelle
```

### Flow

```
┌─────────────────────────────────────────────────────────────┐
│  amsf_survey-real_estate/spec/integration/arelle_spec.rb    │
│                                                             │
│  1. Build Submission with test data                         │
│  2. Generate XBRL via AmsfSurvey.to_xbrl(submission)        │
│  3. POST to arelle_api/validate                             │
│  4. Assert response["valid"] == true                        │
│  5. On failure: show Arelle's error messages                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  arelle_api (localhost:8000)                │
└─────────────────────────────────────────────────────────────┘
```

## Key Decisions

1. **Tests live in plugin gem** - Core gem stays ignorant of industries. Each plugin tests its own taxonomy.

2. **Tagged `:arelle`** - Skipped by default, run explicitly. Requires arelle_api running.

3. **Discovery approach** - Start with empty submission, iterate based on Arelle errors until valid.

4. **No mocking** - Real HTTP calls to real Arelle validator.

## Files to Create

### spec/support/arelle_helper.rb

HTTP helper for validation calls.

```ruby
# frozen_string_literal: true

require "net/http"
require "json"

module ArelleHelper
  ARELLE_URL = ENV.fetch("ARELLE_API_URL", "http://localhost:8000")

  def validate_xbrl(xml)
    uri = URI("#{ARELLE_URL}/validate")
    response = Net::HTTP.post(uri, xml, "Content-Type" => "application/xml")
    JSON.parse(response.body)
  end

  def arelle_available?
    uri = URI("#{ARELLE_URL}/docs")
    Net::HTTP.get_response(uri).is_a?(Net::HTTPSuccess)
  rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
    false
  end
end
```

### spec/integration/arelle_validation_spec.rb

Validation tests.

```ruby
# frozen_string_literal: true

require "spec_helper"
require_relative "../support/arelle_helper"

RSpec.describe "Arelle XBRL Validation", :arelle do
  include ArelleHelper

  before(:all) do
    skip "Arelle API not available" unless arelle_available?
  end

  def build_submission(data = {})
    submission = AmsfSurvey::Submission.new(
      industry: :real_estate,
      year: 2025,
      entity_id: "RE_TEST_001",
      period: Date.new(2025, 12, 31)
    )
    data.each { |k, v| submission[k] = v }
    submission
  end

  describe "minimal valid submission" do
    it "generates valid XBRL" do
      submission = build_submission({})

      xml = AmsfSurvey.to_xbrl(submission)
      result = validate_xbrl(xml)

      unless result["valid"]
        puts "\n=== Arelle Validation Errors ==="
        result["messages"].each do |msg|
          next if msg["severity"] == "info"
          puts "#{msg['severity'].upcase}: #{msg['message']}"
        end
        puts "================================\n"
      end

      expect(result["valid"]).to be true
    end
  end
end
```

### Rakefile addition

```ruby
desc "Run Arelle validation tests (requires arelle_api running)"
task :validate do
  sh "ARELLE=1 bundle exec rspec spec/integration --tag arelle"
end
```

### spec_helper.rb update

```ruby
# Filter arelle tests unless ARELLE env var set
config.filter_run_excluding arelle: true unless ENV["ARELLE"]
```

## Developer Workflow

```bash
# Terminal 1: Start arelle_api
cd arelle_api
uv run uvicorn app.main:app --port 8000

# Terminal 2: Run validation tests
cd amsf_survey/amsf_survey-real_estate
rake validate
# Or: ARELLE=1 bundle exec rspec --tag arelle
```

## Test Cases

1. **Minimal valid submission** - Discover minimum fields for valid XBRL
2. **Complete submission** - All fields populated
3. **Invalid enum value** - Should fail with specific error
4. **Type mismatch** - String where integer expected
5. **Missing required context** - Omit entity_id or period

## Schema URL and Taxonomy Sync

### Source of Truth

Plugin gems own their taxonomy files. arelle_api's cache is derived.

```
amsf_survey-real_estate/taxonomies/2025/   ← Source of truth
arelle_api/cache/http/amsf.mc/...          ← Derived (synced)
```

### Schema URL per Year

Each taxonomy year has a `taxonomy.yml` with its schema URL:

```yaml
# amsf_survey-real_estate/taxonomies/2025/taxonomy.yml
schema_url: http://amsf.mc/fr/taxonomy/strix/2025/strix.xsd
```

The core gem reads this and uses it in generated XBRL:

```xml
<link:schemaRef xlink:href="http://amsf.mc/fr/taxonomy/strix/2025/strix.xsd"/>
```

### Sync Script

Lives in monorepo root. Syncs all plugin taxonomies to arelle_api cache.

```bash
# From amsf_survey/ root
rake arelle:sync
```

The script:
1. Finds all plugin gems (`amsf_survey-*/`)
2. For each, reads `taxonomies/{year}/taxonomy.yml`
3. Parses schema_url to determine arelle_api cache path
4. Copies taxonomy files to that path

### Adding a New Industry

1. Create `amsf_survey-yacht_brokers/` plugin gem
2. Add taxonomy files to `taxonomies/2025/`
3. Create `taxonomies/2025/taxonomy.yml` with schema_url
4. Run `rake arelle:sync`
5. Tests just work

### Core Gem Changes

1. **Taxonomy::Loader** reads `taxonomy.yml` and stores `schema_url` on Questionnaire
2. **Generator** uses `questionnaire.schema_url` for schemaRef href
3. **Registry** exposes `schema_url_for(industry, year)` for sync script

## Future: Runtime Validation (Phase 2)

After development workflow is working, add user-facing validation in immo_crm:
- User clicks "Validate" before submitting to AMSF
- immo_crm calls arelle_api directly
- Shows validation errors in UI
