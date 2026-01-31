# Explicit Question Numbering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add explicit question numbering and Part hierarchy to match the PDF structure (Part → Section → Subsection → Question).

**Architecture:** Add a new `Part` class as the top-level container. Questionnaire holds Parts, Parts hold Sections. Question numbers are explicit in YAML and reset per Part. StructureParser reads the new `parts` top-level key.

**Tech Stack:** Ruby 3.2+, RSpec

---

### Task 1: Create Part Class

**Files:**
- Create: `amsf_survey/lib/amsf_survey/part.rb`
- Test: `amsf_survey/spec/amsf_survey/part_spec.rb`

**Step 1: Write the failing test**

Create `amsf_survey/spec/amsf_survey/part_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe AmsfSurvey::Part do
  let(:field1) do
    AmsfSurvey::Field.new(
      id: :t001, type: :integer, xbrl_type: "xbrli:integerItemType",
      label: "Field 1", gate: false
    )
  end

  let(:field2) do
    AmsfSurvey::Field.new(
      id: :t002, type: :string, xbrl_type: "xbrli:stringItemType",
      label: "Field 2", gate: false
    )
  end

  let(:questions) do
    [
      AmsfSurvey::Question.new(number: 1, field: field1, instructions: nil),
      AmsfSurvey::Question.new(number: 2, field: field2, instructions: nil)
    ]
  end

  let(:subsection) do
    AmsfSurvey::Subsection.new(number: "1.1", title: "Sub 1", questions: questions)
  end

  let(:section) do
    AmsfSurvey::Section.new(number: 1, title: "Customer Risk", subsections: [subsection])
  end

  describe "#initialize" do
    it "creates a part with name and sections" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.name).to eq("Inherent Risk")
      expect(part.sections).to eq([section])
    end
  end

  describe "#questions" do
    it "returns all questions from all sections" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.questions).to eq(questions)
    end
  end

  describe "#question_count" do
    it "returns total number of questions" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.question_count).to eq(2)
    end
  end

  describe "#section_count" do
    it "returns number of sections" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.section_count).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns false when part has sections" do
      part = described_class.new(name: "Inherent Risk", sections: [section])

      expect(part.empty?).to be false
    end

    it "returns true when part has no sections" do
      part = described_class.new(name: "Empty", sections: [])

      expect(part.empty?).to be true
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/part_spec.rb -v`
Expected: FAIL with "uninitialized constant AmsfSurvey::Part"

**Step 3: Write minimal implementation**

Create `amsf_survey/lib/amsf_survey/part.rb`:

```ruby
# frozen_string_literal: true

module AmsfSurvey
  # Represents a top-level part from the PDF (e.g., "Inherent Risk", "Controls", "Signatories").
  # Contains sections. Question numbers reset within each part.
  # Immutable value object built by the taxonomy loader.
  class Part
    attr_reader :name, :sections

    def initialize(name:, sections:)
      @name = name
      @sections = sections
    end

    # Returns all questions from all sections in order
    def questions
      sections.flat_map(&:questions)
    end

    # Total number of questions across all sections
    def question_count
      questions.length
    end

    # Number of sections
    def section_count
      sections.length
    end

    # Returns true if part has no sections
    def empty?
      sections.empty?
    end
  end
end
```

**Step 4: Require the new file in main module**

Modify `amsf_survey/lib/amsf_survey.rb` - add after `require_relative "amsf_survey/section"`:

```ruby
require_relative "amsf_survey/part"
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/part_spec.rb -v`
Expected: PASS (all examples)

**Step 6: Commit**

```bash
git add amsf_survey/lib/amsf_survey/part.rb amsf_survey/spec/amsf_survey/part_spec.rb amsf_survey/lib/amsf_survey.rb
git commit -m "feat: add Part class for top-level hierarchy"
```

---

### Task 2: Update Subsection to Accept String Numbers

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/subsection.rb`
- Modify: `amsf_survey/spec/amsf_survey/subsection_spec.rb`

**Step 1: Write the failing test**

Add to `amsf_survey/spec/amsf_survey/subsection_spec.rb` (after existing tests):

```ruby
describe "#number" do
  it "accepts string numbers like '1.1'" do
    subsection = described_class.new(number: "1.1", title: "Test", questions: [])
    expect(subsection.number).to eq("1.1")
  end

  it "accepts integer numbers" do
    subsection = described_class.new(number: 1, title: "Test", questions: [])
    expect(subsection.number).to eq(1)
  end
end
```

**Step 2: Run test to verify it passes (no changes needed)**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/subsection_spec.rb -v`
Expected: PASS (Ruby duck typing means strings already work)

**Step 3: Update existing fixtures/tests to use string numbers**

No code changes needed - the class already accepts any type. The YAML will provide strings.

**Step 4: Commit**

```bash
git add amsf_survey/spec/amsf_survey/subsection_spec.rb
git commit -m "test: verify Subsection accepts string numbers"
```

---

### Task 3: Update Questionnaire to Hold Parts

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/questionnaire.rb`
- Modify: `amsf_survey/spec/amsf_survey/questionnaire_spec.rb`

**Step 1: Write the failing test**

Add to `amsf_survey/spec/amsf_survey/questionnaire_spec.rb`:

```ruby
describe "parts-based structure" do
  let(:part1) { AmsfSurvey::Part.new(name: "Inherent Risk", sections: [section1]) }
  let(:part2) { AmsfSurvey::Part.new(name: "Controls", sections: [section2]) }

  let(:parts_questionnaire) do
    described_class.new(
      industry: :test_industry,
      year: 2025,
      parts: [part1, part2]
    )
  end

  describe "#parts" do
    it "returns all parts" do
      expect(parts_questionnaire.parts).to eq([part1, part2])
    end
  end

  describe "#sections (backward compatibility)" do
    it "returns sections from all parts" do
      expect(parts_questionnaire.sections).to eq([section1, section2])
    end
  end

  describe "#questions" do
    it "returns questions from all parts" do
      expect(parts_questionnaire.questions).to eq([q1, q2, q3, q4, q5])
    end
  end

  describe "#part_count" do
    it "returns number of parts" do
      expect(parts_questionnaire.part_count).to eq(2)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/questionnaire_spec.rb -v`
Expected: FAIL with "unknown keyword: :parts"

**Step 3: Write minimal implementation**

Replace `amsf_survey/lib/amsf_survey/questionnaire.rb`:

```ruby
# frozen_string_literal: true

module AmsfSurvey
  # Container for an industry/year survey structure.
  # Immutable value object built by the taxonomy loader.
  class Questionnaire
    attr_reader :industry, :year, :parts, :taxonomy_namespace

    def initialize(industry:, year:, parts: nil, sections: nil, taxonomy_namespace: nil)
      @industry = industry
      @year = year
      @taxonomy_namespace = taxonomy_namespace

      # Support both parts-based and legacy sections-based initialization
      if parts
        @parts = parts
      elsif sections
        # Legacy: wrap sections in a single unnamed part for backward compatibility
        @parts = [Part.new(name: nil, sections: sections)]
      else
        @parts = []
      end

      @question_index = build_question_index
    end

    # Returns all sections from all parts (backward compatible)
    def sections
      parts.flat_map(&:sections)
    end

    # Returns all questions from all parts in order
    def questions
      parts.flat_map(&:questions)
    end

    # Lookup question by lowercase ID
    # Input is normalized to lowercase for consistent lookup
    #
    # @param id [Symbol, String] the field identifier (any casing)
    # @return [Question, nil] the question or nil if not found
    def question(id)
      @question_index[id.to_s.downcase.to_sym]
    end

    # Total number of questions
    def question_count
      questions.length
    end

    # Number of sections
    def section_count
      sections.length
    end

    # Number of parts
    def part_count
      parts.length
    end

    # Questions where gate is true
    def gate_questions
      questions.select(&:gate?)
    end

    private

    def build_question_index
      questions.each_with_object({}) do |question, index|
        index[question.id] = question
      end
    end
  end
end
```

**Step 4: Run all questionnaire tests to verify they pass**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/questionnaire_spec.rb -v`
Expected: PASS (all examples including new and legacy tests)

**Step 5: Commit**

```bash
git add amsf_survey/lib/amsf_survey/questionnaire.rb amsf_survey/spec/amsf_survey/questionnaire_spec.rb
git commit -m "feat: update Questionnaire to support parts hierarchy"
```

---

### Task 4: Update StructureParser for New YAML Format

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/taxonomy/structure_parser.rb`
- Modify: `amsf_survey/spec/amsf_survey/taxonomy/structure_parser_spec.rb`
- Modify: `amsf_survey/spec/fixtures/taxonomies/test_industry/2025/questionnaire_structure.yml`

**Step 1: Update test fixture to new format**

Replace `amsf_survey/spec/fixtures/taxonomies/test_industry/2025/questionnaire_structure.yml`:

```yaml
parts:
  - name: "Inherent Risk"
    sections:
      - number: 1
        title: "General"
        subsections:
          - number: "1.1"
            title: "Activity Status"
            questions:
              - field_id: tgate
                question_number: 1
                instructions: |
                  Answer Yes if you performed any regulated activities.
              - field_id: t001
                question_number: 2
              - field_id: t002
                question_number: 3

      - number: 2
        title: "Details"
        subsections:
          - number: "2.1"
            title: "Financial Details"
            questions:
              - field_id: t003
                question_number: 4
                instructions: |
                  Enter total monetary value.
              - field_id: t004
                question_number: 5
```

**Step 2: Write failing tests for new format**

Replace `amsf_survey/spec/amsf_survey/taxonomy/structure_parser_spec.rb`:

```ruby
# frozen_string_literal: true

require "yaml"

RSpec.describe AmsfSurvey::Taxonomy::StructureParser do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }
  let(:structure_path) { File.join(fixtures_path, "questionnaire_structure.yml") }

  describe "#parse" do
    subject(:result) { described_class.new(structure_path).parse }

    it "returns a hash with parts array" do
      expect(result).to be_a(Hash)
      expect(result[:parts]).to be_an(Array)
    end

    it "parses part names" do
      names = result[:parts].map { |p| p[:name] }
      expect(names).to eq(["Inherent Risk"])
    end

    it "parses sections within parts" do
      part = result[:parts].first
      expect(part[:sections].length).to eq(2)
      expect(part[:sections].map { |s| s[:title] }).to eq(["General", "Details"])
    end

    it "parses explicit section numbers" do
      part = result[:parts].first
      expect(part[:sections].map { |s| s[:number] }).to eq([1, 2])
    end

    it "parses subsections with string numbers" do
      part = result[:parts].first
      section = part[:sections].first
      expect(section[:subsections].first[:number]).to eq("1.1")
      expect(section[:subsections].first[:title]).to eq("Activity Status")
    end

    it "parses explicit question numbers" do
      part = result[:parts].first
      section = part[:sections].first
      subsection = section[:subsections].first
      expect(subsection[:questions].map { |q| q[:number] }).to eq([1, 2, 3])
    end

    it "parses field_id as lowercase symbol" do
      part = result[:parts].first
      section = part[:sections].first
      subsection = section[:subsections].first
      expect(subsection[:questions].first[:field_id]).to eq(:tgate)
    end

    it "parses instructions" do
      part = result[:parts].first
      section = part[:sections].first
      subsection = section[:subsections].first
      expect(subsection[:questions].first[:instructions]).to eq(
        "Answer Yes if you performed any regulated activities."
      )
    end

    it "leaves instructions nil when not provided" do
      part = result[:parts].first
      section = part[:sections].first
      subsection = section[:subsections].first
      expect(subsection[:questions][1][:instructions]).to be_nil
    end
  end

  describe "error handling" do
    it "raises MissingStructureFileError when file not found" do
      parser = described_class.new("/nonexistent/path.yml")

      expect { parser.parse }.to raise_error(
        AmsfSurvey::MissingStructureFileError,
        /Structure file not found/
      )
    end

    it "raises MalformedTaxonomyError for invalid YAML" do
      invalid_path = File.join(fixtures_path, "invalid.yml")
      File.write(invalid_path, "{ invalid yaml content")

      parser = described_class.new(invalid_path)
      expect { parser.parse }.to raise_error(AmsfSurvey::MalformedTaxonomyError)
    ensure
      File.delete(invalid_path) if File.exist?(invalid_path)
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/taxonomy/structure_parser_spec.rb -v`
Expected: FAIL with "expected result to have key :parts"

**Step 4: Write minimal implementation**

Replace `amsf_survey/lib/amsf_survey/taxonomy/structure_parser.rb`:

```ruby
# frozen_string_literal: true

require "yaml"

module AmsfSurvey
  module Taxonomy
    # Parses questionnaire_structure.yml to extract PDF-based structure.
    # Supports new parts-based format: Part → Section → Subsection → Question
    class StructureParser
      def initialize(structure_path)
        @structure_path = structure_path
      end

      def parse
        validate_file!
        data = load_yaml

        parts = parse_parts(data["parts"] || [])
        { parts: parts }
      end

      private

      def validate_file!
        return if File.exist?(@structure_path)

        raise MissingStructureFileError, @structure_path
      end

      def load_yaml
        YAML.safe_load(File.read(@structure_path), permitted_classes: [], permitted_symbols: [], aliases: false)
      rescue Psych::SyntaxError => e
        raise MalformedTaxonomyError.new(@structure_path, e.message)
      end

      def parse_parts(parts_data)
        parts_data.map do |part_data|
          parse_part(part_data)
        end
      end

      def parse_part(part_data)
        sections = (part_data["sections"] || []).map do |section_data|
          parse_section(section_data)
        end

        {
          name: part_data["name"],
          sections: sections
        }
      end

      def parse_section(section_data)
        subsections = (section_data["subsections"] || []).map do |sub_data|
          parse_subsection(sub_data)
        end

        {
          number: section_data["number"],
          title: section_data["title"],
          subsections: subsections
        }
      end

      def parse_subsection(sub_data)
        questions = (sub_data["questions"] || []).map do |q_data|
          parse_question(q_data)
        end

        instructions = sub_data["instructions"]&.strip
        instructions = nil if instructions&.empty?

        {
          number: sub_data["number"],
          title: sub_data["title"],
          instructions: instructions,
          questions: questions
        }
      end

      def parse_question(q_data)
        instructions = q_data["instructions"]&.strip
        instructions = nil if instructions&.empty?

        {
          number: q_data["question_number"],
          field_id: q_data["field_id"].to_s.downcase.to_sym,
          instructions: instructions
        }
      end
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/taxonomy/structure_parser_spec.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add amsf_survey/lib/amsf_survey/taxonomy/structure_parser.rb amsf_survey/spec/amsf_survey/taxonomy/structure_parser_spec.rb amsf_survey/spec/fixtures/taxonomies/test_industry/2025/questionnaire_structure.yml
git commit -m "feat: update StructureParser for parts-based YAML format"
```

---

### Task 5: Update Loader to Build Parts

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/taxonomy/loader.rb`
- Modify: `amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb`

**Step 1: Write failing test**

Add to `amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb` (update existing tests):

```ruby
describe "#load" do
  # ... existing tests ...

  it "returns questionnaire with parts" do
    expect(questionnaire.parts).to be_an(Array)
    expect(questionnaire.parts.length).to eq(1)
    expect(questionnaire.parts.first.name).to eq("Inherent Risk")
  end

  it "builds sections within parts" do
    part = questionnaire.parts.first
    expect(part.sections.map(&:title)).to eq(["General", "Details"])
  end

  it "preserves explicit question numbers from YAML" do
    questions = questionnaire.questions
    expect(questions.map(&:number)).to eq([1, 2, 3, 4, 5])
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb -v`
Expected: FAIL

**Step 3: Update Loader implementation**

Replace `amsf_survey/lib/amsf_survey/taxonomy/loader.rb`:

```ruby
# frozen_string_literal: true

module AmsfSurvey
  module Taxonomy
    # Orchestrates parsing of all taxonomy files and builds a Questionnaire.
    # Uses StructureParser for PDF-based part/section/subsection/question hierarchy.
    class Loader
      def initialize(taxonomy_path)
        @taxonomy_path = taxonomy_path
      end

      def load(industry, year)
        # Parse XBRL files for field data
        schema_parser = build_schema_parser
        schema_data = schema_parser.parse
        labels = parse_labels
        xule_data = parse_xule

        # Build field index from XBRL data
        fields = build_fields(schema_data, labels, xule_data)
        field_index = fields.each_with_object({}) { |f, h| h[f.id] = f }

        # Parse structure file and assemble parts
        structure_data = parse_structure
        parts = build_parts(structure_data[:parts], field_index)

        AmsfSurvey::Questionnaire.new(
          industry: industry,
          year: year,
          parts: parts,
          taxonomy_namespace: schema_parser.target_namespace
        )
      end

      private

      def structure_file_path
        File.join(@taxonomy_path, "questionnaire_structure.yml")
      end

      def build_schema_parser
        xsd_files = Dir.glob(File.join(@taxonomy_path, "*.xsd"))
        raise MissingTaxonomyFileError, File.join(@taxonomy_path, "*.xsd") if xsd_files.empty?

        if xsd_files.size > 1
          warn "[TaxonomyLoader] Multiple XSD files found. Using: #{File.basename(xsd_files.first)}. " \
               "Ignored: #{xsd_files[1..].map { |f| File.basename(f) }.join(', ')}"
        end

        SchemaParser.new(xsd_files.first)
      end

      def parse_labels
        lab_files = Dir.glob(File.join(@taxonomy_path, "*_lab.xml"))
        return {} if lab_files.empty?

        LabelParser.new(lab_files.first).parse
      end

      def parse_xule
        xule_files = Dir.glob(File.join(@taxonomy_path, "*.xule"))
        return { gate_rules: {}, gate_fields: [] } if xule_files.empty?

        XuleParser.new(xule_files.first).parse
      end

      def parse_structure
        StructureParser.new(structure_file_path).parse
      end

      def build_fields(schema_data, labels, xule_data)
        schema_data.map do |field_id, schema|
          build_field(field_id, schema, labels, xule_data, schema_data)
        end.compact
      end

      def build_field(field_id, schema, labels, xule_data, schema_data)
        label_data = labels[field_id] || {}
        is_gate = xule_data[:gate_fields].include?(field_id)
        depends_on = resolve_gate_dependencies(xule_data[:gate_rules][field_id], schema_data)

        AmsfSurvey::Field.new(
          id: field_id,
          type: schema[:type],
          xbrl_type: schema[:xbrl_type],
          label: label_data[:label] || field_id.to_s,
          verbose_label: label_data[:verbose_label],
          valid_values: schema[:valid_values],
          depends_on: depends_on,
          gate: is_gate
        )
      end

      # Translates XULE "Yes"/"No" literals to actual valid values from the schema.
      def resolve_gate_dependencies(xule_deps, schema_data)
        return {} if xule_deps.nil? || xule_deps.empty?

        xule_deps.each_with_object({}) do |(gate_id, xule_value), result|
          result[gate_id] = translate_gate_value(xule_value, schema_data[gate_id])
        end
      end

      def translate_gate_value(xule_value, gate_schema)
        return xule_value unless gate_schema && gate_schema[:valid_values]

        valid_values = gate_schema[:valid_values]
        return xule_value unless valid_values.size == 2

        if xule_value == "Yes"
          valid_values.find { |v| v.downcase == "yes" || v.downcase == "oui" } || valid_values.first
        else
          valid_values.find { |v| v.downcase == "no" || v.downcase == "non" } || valid_values.last
        end
      end

      def build_parts(parts_data, field_index)
        seen_fields = {}

        parts_data.map do |part_data|
          sections = part_data[:sections].map do |section_data|
            build_section(section_data, field_index, seen_fields)
          end

          AmsfSurvey::Part.new(
            name: part_data[:name],
            sections: sections
          )
        end
      end

      def build_section(section_data, field_index, seen_fields)
        subsections = section_data[:subsections].map do |sub_data|
          build_subsection(sub_data, field_index, seen_fields, section_data[:title])
        end

        AmsfSurvey::Section.new(
          number: section_data[:number],
          title: section_data[:title],
          subsections: subsections
        )
      end

      def build_subsection(sub_data, field_index, seen_fields, section_title)
        questions = sub_data[:questions].map do |q_data|
          build_question(q_data, field_index, seen_fields, section_title, sub_data[:title])
        end

        AmsfSurvey::Subsection.new(
          number: sub_data[:number],
          title: sub_data[:title],
          instructions: sub_data[:instructions],
          questions: questions
        )
      end

      def build_question(q_data, field_index, seen_fields, section_title, subsection_title)
        field_id = q_data[:field_id]
        location = "#{section_title}, #{subsection_title}"

        # Check for duplicates
        if seen_fields[field_id]
          raise DuplicateFieldError.new(field_id, location)
        end
        seen_fields[field_id] = true

        # Lookup field
        field = field_index[field_id]
        raise UnknownFieldError, field_id unless field

        AmsfSurvey::Question.new(
          number: q_data[:number],
          field: field,
          instructions: q_data[:instructions]
        )
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 6: Commit**

```bash
git add amsf_survey/lib/amsf_survey/taxonomy/loader.rb amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb
git commit -m "feat: update Loader to build parts hierarchy"
```

---

### Task 6: Update Real Estate Taxonomy YAML

**Files:**
- Modify: `amsf_survey-real_estate/taxonomies/2025/questionnaire_structure.yml`

**Step 1: Transform YAML to new format**

Transform the current structure to the parts-based format. This is a manual transformation following the pattern:

```yaml
parts:
  - name: "Inherent Risk"
    sections:
      - number: 1
        title: "Customer Risk"
        subsections:
          - number: "1.1"
            title: "Active in Reporting Cycle"
            questions:
              - field_id: "aACTIVE"
                question_number: 1
                instructions: "Activities subject to the law..."
              # ... Q2-Q215 continue here

      - number: 2
        title: "Products & Services Risk"
        subsections:
          # ... subsections 2.1-2.9

      - number: 3
        title: "Distribution Risk"
        subsections:
          # ... subsections 3.1-3.6

  - name: "Controls"
    sections:
      - number: 4
        title: "Controls"
        subsections:
          - number: "4.1"
            title: "Structure"
            questions:
              - field_id: "aC1102A"
                question_number: 1  # Resets to 1 for Controls
                # ... Q1-Q105

  - name: "Signatories"
    sections:
      - number: 5
        title: "Signatories"
        subsections:
          - number: "5.1"
            title: "Attestation"
            questions:
              - field_id: "aS1"
                question_number: 1  # Resets to 1 for Signatories
              # ... Q1-Q3
```

**Note:** This is a large file (323 questions). The implementer should:
1. Add `parts:` as the top-level key
2. Wrap sections 1-3 in "Inherent Risk" part
3. Wrap section 4 in "Controls" part
4. Wrap section 5 in "Signatories" part
5. Add explicit `number:` to each section
6. Change subsection numbers to strings (e.g., "1.1", "1.2")
7. Add `question_number:` to each question (Q1-215 for Inherent Risk, Q1-105 for Controls, Q1-3 for Signatories)

**Step 2: Run integration tests**

Run: `bundle exec rspec amsf_survey/spec/integration/real_estate_taxonomy_spec.rb -v`
Expected: PASS

**Step 3: Verify question counts**

Add a quick verification:
```ruby
q = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)
puts "Inherent Risk: #{q.parts[0].question_count} questions"  # Should be 215
puts "Controls: #{q.parts[1].question_count} questions"       # Should be 105
puts "Signatories: #{q.parts[2].question_count} questions"    # Should be 3
puts "Total: #{q.question_count}"                              # Should be 323
```

**Step 4: Commit**

```bash
git add amsf_survey-real_estate/taxonomies/2025/questionnaire_structure.yml
git commit -m "feat: transform real estate taxonomy to parts-based format with explicit question numbers"
```

---

### Task 7: Update Integration Tests

**Files:**
- Modify: `amsf_survey/spec/integration/real_estate_taxonomy_spec.rb`

**Step 1: Add tests for parts structure**

Add to `amsf_survey/spec/integration/real_estate_taxonomy_spec.rb`:

```ruby
describe "parts structure" do
  it "has three parts" do
    expect(questionnaire.parts.length).to eq(3)
  end

  it "has correct part names" do
    names = questionnaire.parts.map(&:name)
    expect(names).to eq(["Inherent Risk", "Controls", "Signatories"])
  end

  it "has correct question counts per part" do
    counts = questionnaire.parts.map(&:question_count)
    expect(counts).to eq([215, 105, 3])
  end

  it "has 323 total questions" do
    expect(questionnaire.question_count).to eq(323)
  end
end

describe "explicit question numbers" do
  it "has question numbers starting at 1 for each part" do
    questionnaire.parts.each do |part|
      first_question = part.questions.first
      expect(first_question.number).to eq(1), "Expected first question in #{part.name} to be 1"
    end
  end

  it "has sequential question numbers within Inherent Risk" do
    inherent_risk = questionnaire.parts.find { |p| p.name == "Inherent Risk" }
    numbers = inherent_risk.questions.map(&:number)
    expect(numbers).to eq((1..215).to_a)
  end
end
```

**Step 2: Run tests**

Run: `bundle exec rspec amsf_survey/spec/integration/real_estate_taxonomy_spec.rb -v`
Expected: PASS

**Step 3: Commit**

```bash
git add amsf_survey/spec/integration/real_estate_taxonomy_spec.rb
git commit -m "test: add integration tests for parts structure and question numbering"
```

---

### Task 8: Final Verification

**Step 1: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 2: Update design document with completion status**

Mark the design document as implemented.

**Step 3: Final commit**

```bash
git add docs/plans/2026-01-31-explicit-question-numbering-design.md
git commit -m "docs: mark explicit question numbering design as implemented"
```
