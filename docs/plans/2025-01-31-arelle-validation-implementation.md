# Arelle Validation Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable validation-driven development by integrating amsf_survey-real_estate with arelle_api for XBRL validation.

**Architecture:** Plugin gems own taxonomy files and provide schema_url via taxonomy.yml. Core gem reads schema_url and uses it in generated XBRL. A sync script copies taxonomy files to arelle_api's cache. Validation tests in the plugin gem verify XBRL against Arelle.

**Tech Stack:** Ruby, RSpec, YAML parsing, HTTP client (Net::HTTP), arelle_api (Python/FastAPI)

---

## Current State

Partially implemented:
- `taxonomy.yml` created with schema_url ✓
- `Questionnaire` has schema_url attribute ✓
- `Loader` calls `parse_taxonomy_config` but method doesn't exist ✗
- `Generator` still uses `extract_schema_filename` instead of `schema_url` ✗
- Spec helper and integration test files created but tests fail ✗

---

### Task 1: Add parse_taxonomy_config to Loader

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/taxonomy/loader.rb`
- Test: `amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb`

**Step 1: Write the failing test**

Add to `amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb`:

```ruby
describe "taxonomy.yml parsing" do
  it "loads schema_url from taxonomy.yml" do
    questionnaire = loader.load(:test_industry, 2025)
    expect(questionnaire.schema_url).to eq("http://example.com/test/taxonomy.xsd")
  end

  it "returns nil schema_url when taxonomy.yml is missing" do
    # Use a fixture without taxonomy.yml
    loader_without_config = described_class.new(fixtures_path_without_taxonomy_yml)
    questionnaire = loader_without_config.load(:test_industry, 2025)
    expect(questionnaire.schema_url).to be_nil
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec spec/amsf_survey/taxonomy/loader_spec.rb -e "taxonomy.yml" -v`
Expected: FAIL with "undefined method `parse_taxonomy_config'"

**Step 3: Create test fixture taxonomy.yml**

Create `amsf_survey/spec/fixtures/taxonomies/test_industry/2025/taxonomy.yml`:

```yaml
schema_url: http://example.com/test/taxonomy.xsd
```

**Step 4: Implement parse_taxonomy_config**

Add to `amsf_survey/lib/amsf_survey/taxonomy/loader.rb` in the private section:

```ruby
def parse_taxonomy_config
  config_path = File.join(@taxonomy_path, "taxonomy.yml")
  return {} unless File.exist?(config_path)

  config = YAML.safe_load(File.read(config_path), symbolize_names: true)
  { schema_url: config[:schema_url] }
end
```

**Step 5: Add YAML require**

Add to `amsf_survey/lib/amsf_survey/taxonomy/loader.rb` at the top:

```ruby
require "yaml"
```

**Step 6: Run test to verify it passes**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec spec/amsf_survey/taxonomy/loader_spec.rb -e "taxonomy.yml" -v`
Expected: PASS

**Step 7: Run full test suite**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec`
Expected: All tests pass

**Step 8: Commit**

```bash
cd amsf_survey/amsf_survey
git add lib/amsf_survey/taxonomy/loader.rb spec/amsf_survey/taxonomy/loader_spec.rb spec/fixtures/taxonomies/test_industry/2025/taxonomy.yml
git commit -m "feat(taxonomy): add schema_url parsing from taxonomy.yml

Loader now reads taxonomy.yml and extracts schema_url for XBRL generation.
Returns nil when taxonomy.yml is missing (backward compatible).

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Update Generator to use schema_url

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/generator.rb`
- Test: `amsf_survey/spec/amsf_survey/generator_spec.rb`

**Step 1: Write the failing test**

Add to `amsf_survey/spec/amsf_survey/generator_spec.rb`:

```ruby
describe "schemaRef generation" do
  context "when questionnaire has schema_url" do
    let(:questionnaire_with_url) do
      instance_double(
        AmsfSurvey::Questionnaire,
        taxonomy_namespace: "http://example.com/ns",
        schema_url: "http://amsf.mc/taxonomy/2025/schema.xsd",
        questions: []
      )
    end

    it "uses schema_url for schemaRef href" do
      allow(submission).to receive(:questionnaire).and_return(questionnaire_with_url)

      xml = generator.generate
      doc = Nokogiri::XML(xml)

      schema_ref = doc.at_xpath("//link:schemaRef", "link" => "http://www.xbrl.org/2003/linkbase")
      expect(schema_ref["xlink:href"]).to eq("http://amsf.mc/taxonomy/2025/schema.xsd")
    end
  end

  context "when questionnaire has no schema_url" do
    it "falls back to extract_schema_filename" do
      xml = generator.generate
      doc = Nokogiri::XML(xml)

      schema_ref = doc.at_xpath("//link:schemaRef", "link" => "http://www.xbrl.org/2003/linkbase")
      # Falls back to extracting from namespace
      expect(schema_ref["xlink:href"]).to match(/\.xsd$/)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec spec/amsf_survey/generator_spec.rb -e "schemaRef" -v`
Expected: FAIL - still using extract_schema_filename

**Step 3: Update build_schema_ref method**

Replace in `amsf_survey/lib/amsf_survey/generator.rb`:

```ruby
# Build the schemaRef element
def build_schema_ref(doc, parent)
  schema_ref = Nokogiri::XML::Node.new("schemaRef", doc)
  schema_ref.namespace = parent.namespace_definitions.find { |ns| ns.prefix == "link" }
  schema_ref["xlink:type"] = "simple"
  schema_ref["xlink:href"] = schema_href
  parent.add_child(schema_ref)
end

# Determine the schema href - prefer explicit schema_url, fall back to extraction
def schema_href
  questionnaire.schema_url || extract_schema_filename
end
```

**Step 4: Run test to verify it passes**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec spec/amsf_survey/generator_spec.rb -e "schemaRef" -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec`
Expected: All tests pass

**Step 6: Commit**

```bash
cd amsf_survey/amsf_survey
git add lib/amsf_survey/generator.rb spec/amsf_survey/generator_spec.rb
git commit -m "feat(generator): use schema_url for schemaRef href

Generator now uses questionnaire.schema_url when available,
falling back to extract_schema_filename for backward compatibility.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Add schema_url_for to Registry

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/registry.rb`
- Test: `amsf_survey/spec/amsf_survey/registry_spec.rb`

**Step 1: Write the failing test**

Add to `amsf_survey/spec/amsf_survey/registry_spec.rb`:

```ruby
describe ".schema_url_for" do
  before do
    AmsfSurvey.register_plugin(
      industry: :test_industry,
      taxonomy_path: fixtures_path
    )
  end

  it "returns schema_url for registered industry and year" do
    url = AmsfSurvey.schema_url_for(industry: :test_industry, year: 2025)
    expect(url).to eq("http://example.com/test/taxonomy.xsd")
  end

  it "returns nil for unregistered industry" do
    url = AmsfSurvey.schema_url_for(industry: :unknown, year: 2025)
    expect(url).to be_nil
  end

  it "returns nil for unsupported year" do
    url = AmsfSurvey.schema_url_for(industry: :test_industry, year: 1999)
    expect(url).to be_nil
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec spec/amsf_survey/registry_spec.rb -e "schema_url_for" -v`
Expected: FAIL with "undefined method `schema_url_for'"

**Step 3: Implement schema_url_for**

Add to `amsf_survey/lib/amsf_survey/registry.rb` in the public class methods:

```ruby
# Get schema_url for an industry and year (for sync scripts)
# @param industry [Symbol] the industry identifier
# @param year [Integer] the taxonomy year
# @return [String, nil] the schema URL or nil if not available
def schema_url_for(industry:, year:)
  return nil unless registered?(industry)
  return nil unless supported_years(industry).include?(year)

  questionnaire(industry: industry, year: year).schema_url
end
```

**Step 4: Run test to verify it passes**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec spec/amsf_survey/registry_spec.rb -e "schema_url_for" -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `cd amsf_survey/amsf_survey && bundle exec rspec`
Expected: All tests pass

**Step 6: Commit**

```bash
cd amsf_survey/amsf_survey
git add lib/amsf_survey/registry.rb spec/amsf_survey/registry_spec.rb
git commit -m "feat(registry): add schema_url_for method

Exposes schema_url for sync scripts to determine arelle_api cache paths.
Returns nil for unregistered industries or unsupported years.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Task 4: Create arelle:sync rake task

**Files:**
- Create: `amsf_survey/Rakefile`
- Create: `amsf_survey/lib/tasks/arelle.rake`

**Step 1: Create the rake task file**

Create `amsf_survey/lib/tasks/arelle.rake`:

```ruby
# frozen_string_literal: true

namespace :arelle do
  desc "Sync taxonomy files to arelle_api cache"
  task :sync do
    require "fileutils"
    require "yaml"
    require "uri"

    arelle_cache = ENV.fetch("ARELLE_CACHE_PATH") do
      File.expand_path("../../arelle_api/cache", __dir__)
    end

    # Find all plugin gems
    plugin_dirs = Dir.glob(File.join(__dir__, "../../amsf_survey-*/"))

    plugin_dirs.each do |plugin_dir|
      plugin_name = File.basename(plugin_dir)
      taxonomy_base = File.join(plugin_dir, "taxonomies")

      next unless File.directory?(taxonomy_base)

      # Process each year
      Dir.children(taxonomy_base).each do |year|
        year_path = File.join(taxonomy_base, year)
        next unless File.directory?(year_path)

        config_path = File.join(year_path, "taxonomy.yml")
        next unless File.exist?(config_path)

        config = YAML.safe_load(File.read(config_path), symbolize_names: true)
        schema_url = config[:schema_url]
        next unless schema_url

        # Parse URL to determine cache path
        uri = URI.parse(schema_url)
        cache_dir = File.join(arelle_cache, uri.scheme, uri.host, File.dirname(uri.path))

        puts "Syncing #{plugin_name}/#{year} -> #{cache_dir}"

        # Create cache directory
        FileUtils.mkdir_p(cache_dir)

        # Copy taxonomy files (xsd, xml, but not yml)
        Dir.glob(File.join(year_path, "*.{xsd,xml}")).each do |file|
          dest = File.join(cache_dir, File.basename(file))
          FileUtils.cp(file, dest)
          puts "  Copied #{File.basename(file)}"
        end

        # Create entry point XSD if different from main schema
        entry_xsd = File.basename(uri.path)
        main_xsd = Dir.glob(File.join(cache_dir, "*.xsd")).first
        if main_xsd && File.basename(main_xsd) != entry_xsd
          entry_path = File.join(cache_dir, entry_xsd)
          unless File.exist?(entry_path)
            FileUtils.cp(main_xsd, entry_path)
            puts "  Created entry point #{entry_xsd}"
          end
        end
      end
    end

    puts "Sync complete!"
  end
end
```

**Step 2: Create or update Rakefile**

Create `amsf_survey/Rakefile`:

```ruby
# frozen_string_literal: true

Dir.glob("lib/tasks/*.rake").each { |r| load r }
```

**Step 3: Test the rake task manually**

Run: `cd amsf_survey && rake arelle:sync`
Expected: Output showing files being copied to arelle_api cache

**Step 4: Verify files exist in arelle_api cache**

Run: `ls -la ../arelle_api/cache/http/amsf.mc/fr/taxonomy/strix/2025/`
Expected: XSD and XML files present

**Step 5: Commit**

```bash
cd amsf_survey
git add Rakefile lib/tasks/arelle.rake
git commit -m "feat: add arelle:sync rake task

Syncs taxonomy files from plugin gems to arelle_api cache.
Reads schema_url from taxonomy.yml to determine cache path.

Usage: rake arelle:sync
Set ARELLE_CACHE_PATH to override default location.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Verify Arelle validation works

**Files:**
- Already created: `amsf_survey-real_estate/spec/integration/arelle_validation_spec.rb`
- Already created: `amsf_survey-real_estate/spec/support/arelle_helper.rb`

**Step 1: Ensure arelle_api is running**

Run: `cd ../arelle_api && uv run uvicorn app.main:app --port 8000 &`

**Step 2: Run the validation test**

Run: `cd amsf_survey/amsf_survey-real_estate && ARELLE=1 bundle exec rspec spec/integration/arelle_validation_spec.rb -v`

Expected: Either PASS (if XBRL is valid) or FAIL with specific Arelle validation errors to iterate on.

**Step 3: If validation fails, note the errors**

The test output will show Arelle's errors. These guide what to fix in the gem.

**Step 4: Commit the working integration**

```bash
cd amsf_survey
git add amsf_survey-real_estate/spec/
git commit -m "feat(real_estate): add Arelle validation integration tests

Tests generate XBRL and validate against running arelle_api.
Tagged :arelle, skipped by default. Run with ARELLE=1.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Task 6: Add validate rake task to plugin

**Files:**
- Modify: `amsf_survey-real_estate/Rakefile`

**Step 1: Read current Rakefile**

Check if Rakefile exists and what's in it.

**Step 2: Add validate task**

Add to `amsf_survey-real_estate/Rakefile`:

```ruby
desc "Run Arelle validation tests (requires arelle_api running)"
task :validate do
  sh "ARELLE=1 bundle exec rspec spec/integration --tag arelle"
end
```

**Step 3: Test the task**

Run: `cd amsf_survey/amsf_survey-real_estate && rake validate`
Expected: Runs the Arelle validation tests

**Step 4: Commit**

```bash
cd amsf_survey/amsf_survey-real_estate
git add Rakefile
git commit -m "feat: add rake validate task for Arelle testing

Convenience task to run integration tests against arelle_api.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Summary

After completing all tasks:

1. Core gem reads `schema_url` from `taxonomy.yml`
2. Generator uses `schema_url` in XBRL output
3. Registry exposes `schema_url_for` for sync scripts
4. `rake arelle:sync` copies taxonomy files to arelle_api cache
5. Plugin gem has `rake validate` for running Arelle tests
6. Validation-driven development workflow is operational

**Developer workflow:**
```bash
# One-time setup
cd amsf_survey && rake arelle:sync

# Development loop
cd amsf_survey-real_estate
# Edit code...
rake validate  # See Arelle errors
# Fix issues...
rake validate  # Repeat until valid
```
