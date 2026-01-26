# Questionnaire Structure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace XBRL-based presentation structure with human-readable PDF structure via a YAML mapping file.

**Architecture:** Add `questionnaire_structure.yml` per industry/year that defines sections, subsections, and questions. The `Loader` parses this file and builds `Section` → `Subsection` → `Question` hierarchy, where each `Question` wraps an XBRL `Field` with additional metadata (number, instructions).

**Tech Stack:** Ruby, YAML parsing (Psych stdlib), RSpec for testing.

---

## Task 1: Add New Error Classes

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/errors.rb`
- Test: `amsf_survey/spec/amsf_survey/errors_spec.rb`

**Step 1: Write failing tests for new error classes**

Add to `errors_spec.rb`:

```ruby
describe AmsfSurvey::MissingStructureFileError do
  it "includes file path in message" do
    error = described_class.new("/path/to/missing.yml")
    expect(error.message).to eq("Structure file not found: /path/to/missing.yml")
    expect(error.file_path).to eq("/path/to/missing.yml")
  end
end

describe AmsfSurvey::DuplicateFieldError do
  it "includes field id and location in message" do
    error = described_class.new(:aactive, "Section 1, Subsection 2")
    expect(error.message).to eq("Duplicate field 'aactive' in Section 1, Subsection 2")
    expect(error.field_id).to eq(:aactive)
    expect(error.location).to eq("Section 1, Subsection 2")
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/amsf_survey/errors_spec.rb -v`
Expected: FAIL with "uninitialized constant"

**Step 3: Implement the error classes**

Add to `errors.rb`:

```ruby
# Raised when questionnaire_structure.yml is not found
class MissingStructureFileError < TaxonomyLoadError
  attr_reader :file_path

  def initialize(file_path)
    @file_path = file_path
    super("Structure file not found: #{file_path}")
  end
end

# Raised when a field appears multiple times in questionnaire_structure.yml
class DuplicateFieldError < TaxonomyLoadError
  attr_reader :field_id, :location

  def initialize(field_id, location)
    @field_id = field_id
    @location = location
    super("Duplicate field '#{field_id}' in #{location}")
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/amsf_survey/errors_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add amsf_survey/lib/amsf_survey/errors.rb amsf_survey/spec/amsf_survey/errors_spec.rb
git commit -m "feat: add MissingStructureFileError and DuplicateFieldError"
```

---

## Task 2: Create Question Class

**Files:**
- Create: `amsf_survey/lib/amsf_survey/question.rb`
- Test: `amsf_survey/spec/amsf_survey/question_spec.rb`

**Step 1: Write failing test for Question class**

Create `question_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe AmsfSurvey::Question do
  let(:field) do
    AmsfSurvey::Field.new(
      id: :aACTIVE,
      type: :boolean,
      xbrl_type: "test:booleanItemType",
      label: "Are you active?",
      section_id: :test,
      gate: true,
      verbose_label: "Extended label",
      valid_values: %w[Oui Non],
      depends_on: {}
    )
  end

  describe "#initialize" do
    it "creates a question with number, instructions, and field" do
      question = described_class.new(number: 1, field: field, instructions: "Help text")

      expect(question.number).to eq(1)
      expect(question.instructions).to eq("Help text")
    end

    it "allows nil instructions" do
      question = described_class.new(number: 1, field: field, instructions: nil)

      expect(question.instructions).to be_nil
    end
  end

  describe "delegation to field" do
    subject(:question) { described_class.new(number: 1, field: field, instructions: nil) }

    it "delegates id to field" do
      expect(question.id).to eq(:aactive)
    end

    it "delegates xbrl_id to field" do
      expect(question.xbrl_id).to eq(:aACTIVE)
    end

    it "delegates label to field" do
      expect(question.label).to eq("Are you active?")
    end

    it "delegates verbose_label to field" do
      expect(question.verbose_label).to eq("Extended label")
    end

    it "delegates type to field" do
      expect(question.type).to eq(:boolean)
    end

    it "delegates valid_values to field" do
      expect(question.valid_values).to eq(%w[Oui Non])
    end

    it "delegates gate? to field" do
      expect(question.gate?).to be true
    end

    it "delegates depends_on to field" do
      expect(question.depends_on).to eq({})
    end
  end

  describe "#visible?" do
    let(:gated_field) do
      AmsfSurvey::Field.new(
        id: :t001,
        type: :integer,
        xbrl_type: "xbrli:integerItemType",
        label: "Count",
        section_id: :test,
        gate: false,
        depends_on: { tGATE: "Oui" }
      )
    end

    subject(:question) { described_class.new(number: 1, field: gated_field, instructions: nil) }

    it "returns true when dependencies are satisfied" do
      expect(question.visible?({ tGATE: "Oui" })).to be true
    end

    it "returns false when dependencies are not satisfied" do
      expect(question.visible?({ tGATE: "Non" })).to be false
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/amsf_survey/question_spec.rb -v`
Expected: FAIL with "uninitialized constant AmsfSurvey::Question"

**Step 3: Implement Question class**

Create `question.rb`:

```ruby
# frozen_string_literal: true

module AmsfSurvey
  # Wraps a Field with PDF-sourced metadata (question number, instructions).
  # Delegates XBRL attributes to the underlying Field.
  class Question
    attr_reader :number, :instructions, :field

    def initialize(number:, field:, instructions:)
      @number = number
      @field = field
      @instructions = instructions
    end

    # Delegate XBRL attributes to field
    def id = field.id
    def xbrl_id = field.xbrl_id
    def label = field.label
    def verbose_label = field.verbose_label
    def type = field.type
    def valid_values = field.valid_values
    def gate? = field.gate?
    def depends_on = field.depends_on

    # Evaluate visibility based on gate dependencies
    def visible?(data)
      field.send(:visible?, data)
    end
  end
end
```

**Step 4: Require the new file in main module**

Add to `amsf_survey/lib/amsf_survey.rb` after the Field require:

```ruby
require_relative "amsf_survey/question"
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/amsf_survey/question_spec.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add amsf_survey/lib/amsf_survey/question.rb amsf_survey/spec/amsf_survey/question_spec.rb amsf_survey/lib/amsf_survey.rb
git commit -m "feat: add Question class wrapping Field with number and instructions"
```

---

## Task 3: Create Subsection Class

**Files:**
- Create: `amsf_survey/lib/amsf_survey/subsection.rb`
- Test: `amsf_survey/spec/amsf_survey/subsection_spec.rb`

**Step 1: Write failing test for Subsection class**

Create `subsection_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe AmsfSurvey::Subsection do
  let(:field1) do
    AmsfSurvey::Field.new(
      id: :t001, type: :integer, xbrl_type: "xbrli:integerItemType",
      label: "Field 1", section_id: :test, gate: false
    )
  end

  let(:field2) do
    AmsfSurvey::Field.new(
      id: :t002, type: :string, xbrl_type: "xbrli:stringItemType",
      label: "Field 2", section_id: :test, gate: false
    )
  end

  let(:questions) do
    [
      AmsfSurvey::Question.new(number: 1, field: field1, instructions: "Help 1"),
      AmsfSurvey::Question.new(number: 2, field: field2, instructions: nil)
    ]
  end

  describe "#initialize" do
    it "creates a subsection with number, title, and questions" do
      subsection = described_class.new(
        number: 1,
        title: "Soumis à la loi",
        questions: questions
      )

      expect(subsection.number).to eq(1)
      expect(subsection.title).to eq("Soumis à la loi")
      expect(subsection.questions).to eq(questions)
    end
  end

  describe "#question_count" do
    it "returns the number of questions" do
      subsection = described_class.new(number: 1, title: "Test", questions: questions)
      expect(subsection.question_count).to eq(2)
    end
  end

  describe "#empty?" do
    it "returns false when subsection has questions" do
      subsection = described_class.new(number: 1, title: "Test", questions: questions)
      expect(subsection.empty?).to be false
    end

    it "returns true when subsection has no questions" do
      subsection = described_class.new(number: 1, title: "Test", questions: [])
      expect(subsection.empty?).to be true
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/amsf_survey/subsection_spec.rb -v`
Expected: FAIL with "uninitialized constant AmsfSurvey::Subsection"

**Step 3: Implement Subsection class**

Create `subsection.rb`:

```ruby
# frozen_string_literal: true

module AmsfSurvey
  # Represents a logical grouping of questions within a section (e.g., "1.1", "1.2").
  # Immutable value object built by the taxonomy loader.
  class Subsection
    attr_reader :number, :title, :questions

    def initialize(number:, title:, questions:)
      @number = number
      @title = title
      @questions = questions
    end

    def question_count
      questions.length
    end

    def empty?
      questions.empty?
    end
  end
end
```

**Step 4: Require the new file in main module**

Add to `amsf_survey/lib/amsf_survey.rb` after the Question require:

```ruby
require_relative "amsf_survey/subsection"
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/amsf_survey/subsection_spec.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add amsf_survey/lib/amsf_survey/subsection.rb amsf_survey/spec/amsf_survey/subsection_spec.rb amsf_survey/lib/amsf_survey.rb
git commit -m "feat: add Subsection class with number, title, and questions"
```

---

## Task 4: Refactor Section Class

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/section.rb`
- Rewrite: `amsf_survey/spec/amsf_survey/section_spec.rb`

**Step 1: Write new tests for refactored Section**

Replace contents of `section_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe AmsfSurvey::Section do
  let(:field1) do
    AmsfSurvey::Field.new(
      id: :t001, type: :integer, xbrl_type: "xbrli:integerItemType",
      label: "Field 1", section_id: :test, gate: false
    )
  end

  let(:field2) do
    AmsfSurvey::Field.new(
      id: :t002, type: :string, xbrl_type: "xbrli:stringItemType",
      label: "Field 2", section_id: :test, gate: false
    )
  end

  let(:questions) do
    [
      AmsfSurvey::Question.new(number: 1, field: field1, instructions: nil),
      AmsfSurvey::Question.new(number: 2, field: field2, instructions: nil)
    ]
  end

  let(:subsection) do
    AmsfSurvey::Subsection.new(number: 1, title: "Sub 1", questions: questions)
  end

  describe "#initialize" do
    it "creates a section with number, title, and subsections" do
      section = described_class.new(
        number: 1,
        title: "Inherent Risk",
        subsections: [subsection]
      )

      expect(section.number).to eq(1)
      expect(section.title).to eq("Inherent Risk")
      expect(section.subsections).to eq([subsection])
    end
  end

  describe "#questions" do
    it "returns all questions from all subsections" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection]
      )

      expect(section.questions).to eq(questions)
    end

    it "returns questions in order across multiple subsections" do
      field3 = AmsfSurvey::Field.new(
        id: :t003, type: :boolean, xbrl_type: "xbrli:booleanItemType",
        label: "Field 3", section_id: :test, gate: false
      )
      q3 = AmsfSurvey::Question.new(number: 3, field: field3, instructions: nil)
      subsection2 = AmsfSurvey::Subsection.new(number: 2, title: "Sub 2", questions: [q3])

      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection, subsection2]
      )

      expect(section.questions.map(&:number)).to eq([1, 2, 3])
    end
  end

  describe "#question_count" do
    it "returns total questions across all subsections" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection]
      )

      expect(section.question_count).to eq(2)
    end
  end

  describe "#subsection_count" do
    it "returns the number of subsections" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection]
      )

      expect(section.subsection_count).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns false when section has subsections with questions" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: [subsection]
      )

      expect(section.empty?).to be false
    end

    it "returns true when section has no subsections" do
      section = described_class.new(
        number: 1,
        title: "Test",
        subsections: []
      )

      expect(section.empty?).to be true
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/amsf_survey/section_spec.rb -v`
Expected: FAIL (old Section has different interface)

**Step 3: Rewrite Section class**

Replace contents of `section.rb`:

```ruby
# frozen_string_literal: true

module AmsfSurvey
  # Represents a top-level section from the PDF structure (e.g., "Inherent Risk").
  # Contains subsections which contain questions.
  # Immutable value object built by the taxonomy loader.
  class Section
    attr_reader :number, :title, :subsections

    def initialize(number:, title:, subsections:)
      @number = number
      @title = title
      @subsections = subsections
    end

    # Returns all questions from all subsections in order
    def questions
      subsections.flat_map(&:questions)
    end

    # Total number of questions across all subsections
    def question_count
      questions.length
    end

    # Number of subsections
    def subsection_count
      subsections.length
    end

    # Returns true if section has no subsections
    def empty?
      subsections.empty?
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/amsf_survey/section_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add amsf_survey/lib/amsf_survey/section.rb amsf_survey/spec/amsf_survey/section_spec.rb
git commit -m "refactor: Section now uses number, title, subsections (PDF structure)"
```

---

## Task 5: Create StructureParser Class

**Files:**
- Create: `amsf_survey/lib/amsf_survey/taxonomy/structure_parser.rb`
- Test: `amsf_survey/spec/amsf_survey/taxonomy/structure_parser_spec.rb`
- Create: `amsf_survey/spec/fixtures/taxonomies/test_industry/2025/questionnaire_structure.yml`

**Step 1: Create test fixture YAML file**

Create `questionnaire_structure.yml`:

```yaml
sections:
  - title: "General"
    subsections:
      - title: "Activity Status"
        questions:
          - field_id: tgate
            instructions: |
              Answer Yes if you performed any regulated activities.
          - field_id: t001
          - field_id: t002

  - title: "Details"
    subsections:
      - title: "Financial Details"
        questions:
          - field_id: t003
            instructions: |
              Enter total monetary value.
          - field_id: t004
```

**Step 2: Write failing tests for StructureParser**

Create `structure_parser_spec.rb`:

```ruby
# frozen_string_literal: true

require "yaml"

RSpec.describe AmsfSurvey::Taxonomy::StructureParser do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }
  let(:structure_path) { File.join(fixtures_path, "questionnaire_structure.yml") }

  describe "#parse" do
    subject(:result) { described_class.new(structure_path).parse }

    it "returns a hash with sections array" do
      expect(result).to be_a(Hash)
      expect(result[:sections]).to be_an(Array)
    end

    it "parses section titles" do
      titles = result[:sections].map { |s| s[:title] }
      expect(titles).to eq(["General", "Details"])
    end

    it "assigns section numbers based on position" do
      numbers = result[:sections].map { |s| s[:number] }
      expect(numbers).to eq([1, 2])
    end

    it "parses subsections within sections" do
      general = result[:sections].first
      expect(general[:subsections].length).to eq(1)
      expect(general[:subsections].first[:title]).to eq("Activity Status")
    end

    it "assigns subsection numbers based on position within section" do
      general = result[:sections].first
      expect(general[:subsections].first[:number]).to eq(1)
    end

    it "parses questions within subsections" do
      general = result[:sections].first
      subsection = general[:subsections].first
      expect(subsection[:questions].length).to eq(3)
    end

    it "parses field_id as symbol" do
      general = result[:sections].first
      subsection = general[:subsections].first
      expect(subsection[:questions].first[:field_id]).to eq(:tgate)
    end

    it "parses instructions (strips trailing whitespace)" do
      general = result[:sections].first
      subsection = general[:subsections].first
      expect(subsection[:questions].first[:instructions]).to eq(
        "Answer Yes if you performed any regulated activities."
      )
    end

    it "leaves instructions nil when not provided" do
      general = result[:sections].first
      subsection = general[:subsections].first
      expect(subsection[:questions][1][:instructions]).to be_nil
    end

    it "assigns question numbers scoped to section" do
      general = result[:sections].first
      details = result[:sections].last

      general_q_numbers = general[:subsections].flat_map { |s| s[:questions].map { |q| q[:number] } }
      details_q_numbers = details[:subsections].flat_map { |s| s[:questions].map { |q| q[:number] } }

      expect(general_q_numbers).to eq([1, 2, 3])
      expect(details_q_numbers).to eq([1, 2])  # Restarts at 1
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

**Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/amsf_survey/taxonomy/structure_parser_spec.rb -v`
Expected: FAIL with "uninitialized constant"

**Step 4: Implement StructureParser**

Create `structure_parser.rb`:

```ruby
# frozen_string_literal: true

require "yaml"

module AmsfSurvey
  module Taxonomy
    # Parses questionnaire_structure.yml to extract PDF-based structure.
    class StructureParser
      def initialize(structure_path)
        @structure_path = structure_path
      end

      def parse
        validate_file!
        data = load_yaml

        sections = parse_sections(data["sections"] || [])
        { sections: sections }
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

      def parse_sections(sections_data)
        sections_data.each_with_index.map do |section_data, index|
          parse_section(section_data, index + 1)
        end
      end

      def parse_section(section_data, section_number)
        question_counter = 0
        subsections = (section_data["subsections"] || []).each_with_index.map do |sub_data, index|
          subsection, question_counter = parse_subsection(sub_data, index + 1, question_counter)
          subsection
        end

        {
          number: section_number,
          title: section_data["title"],
          subsections: subsections
        }
      end

      def parse_subsection(sub_data, subsection_number, question_counter)
        questions = (sub_data["questions"] || []).map do |q_data|
          question_counter += 1
          parse_question(q_data, question_counter)
        end

        subsection = {
          number: subsection_number,
          title: sub_data["title"],
          questions: questions
        }

        [subsection, question_counter]
      end

      def parse_question(q_data, question_number)
        instructions = q_data["instructions"]&.strip
        instructions = nil if instructions&.empty?

        {
          number: question_number,
          field_id: q_data["field_id"].to_s.downcase.to_sym,
          instructions: instructions
        }
      end
    end
  end
end
```

**Step 5: Require the new file in main module**

Add to `amsf_survey/lib/amsf_survey.rb` in the taxonomy requires section:

```ruby
require_relative "amsf_survey/taxonomy/structure_parser"
```

**Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/amsf_survey/taxonomy/structure_parser_spec.rb -v`
Expected: PASS

**Step 7: Commit**

```bash
git add amsf_survey/lib/amsf_survey/taxonomy/structure_parser.rb \
        amsf_survey/spec/amsf_survey/taxonomy/structure_parser_spec.rb \
        amsf_survey/spec/fixtures/taxonomies/test_industry/2025/questionnaire_structure.yml \
        amsf_survey/lib/amsf_survey.rb
git commit -m "feat: add StructureParser for questionnaire_structure.yml"
```

---

## Task 6: Refactor Loader to Use StructureParser

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/taxonomy/loader.rb`
- Rewrite: `amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb`

**Step 1: Write new tests for refactored Loader**

Replace contents of `loader_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe AmsfSurvey::Taxonomy::Loader do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }

  describe "#load" do
    subject(:questionnaire) { described_class.new(fixtures_path).load(:test_industry, 2025) }

    it "returns a Questionnaire object" do
      expect(questionnaire).to be_a(AmsfSurvey::Questionnaire)
    end

    it "sets industry and year" do
      expect(questionnaire.industry).to eq(:test_industry)
      expect(questionnaire.year).to eq(2025)
    end

    it "extracts taxonomy_namespace from XSD" do
      expect(questionnaire.taxonomy_namespace).to eq("https://test.example.com/test_industry_2025")
    end

    describe "sections" do
      it "creates sections from structure file" do
        expect(questionnaire.sections.length).to eq(2)
      end

      it "assigns section numbers" do
        expect(questionnaire.sections.map(&:number)).to eq([1, 2])
      end

      it "assigns section titles" do
        expect(questionnaire.sections.map(&:title)).to eq(["General", "Details"])
      end
    end

    describe "subsections" do
      it "creates subsections within sections" do
        general = questionnaire.sections.first
        expect(general.subsections.length).to eq(1)
        expect(general.subsections.first.title).to eq("Activity Status")
      end

      it "assigns subsection numbers" do
        general = questionnaire.sections.first
        expect(general.subsections.first.number).to eq(1)
      end
    end

    describe "questions" do
      it "creates questions within subsections" do
        general = questionnaire.sections.first
        subsection = general.subsections.first
        expect(subsection.questions.length).to eq(3)
      end

      it "assigns question numbers scoped to section" do
        general = questionnaire.sections.first
        details = questionnaire.sections.last

        expect(general.questions.map(&:number)).to eq([1, 2, 3])
        expect(details.questions.map(&:number)).to eq([1, 2])
      end

      it "includes instructions from structure file" do
        general = questionnaire.sections.first
        q1 = general.questions.first
        expect(q1.instructions).to include("Answer Yes if you performed")
      end

      it "leaves instructions nil when not in structure file" do
        general = questionnaire.sections.first
        q2 = general.questions[1]
        expect(q2.instructions).to be_nil
      end

      it "wraps Field with correct XBRL data" do
        general = questionnaire.sections.first
        q1 = general.questions.first

        expect(q1.id).to eq(:tgate)
        expect(q1.type).to eq(:boolean)
        expect(q1.label).to eq("Avez-vous effectue des activites?")
      end

      it "preserves gate dependencies" do
        general = questionnaire.sections.first
        q2 = general.questions[1]  # t001 depends on tGATE

        expect(q2.depends_on).to eq({ tGATE: "Oui" })
      end
    end

    describe "field lookup" do
      it "supports direct field lookup by lowercase ID" do
        field = questionnaire.field(:tgate)
        expect(field).to be_a(AmsfSurvey::Field)
        expect(field.id).to eq(:tgate)
      end

      it "normalizes field lookup to lowercase" do
        expect(questionnaire.field(:TGATE)).to eq(questionnaire.field(:tgate))
      end
    end

    describe "error handling" do
      it "raises UnknownFieldError for invalid field_id in structure" do
        # Create a structure file with invalid field
        bad_structure = File.join(fixtures_path, "bad_structure.yml")
        File.write(bad_structure, <<~YAML)
          sections:
            - title: "Test"
              subsections:
                - title: "Sub"
                  questions:
                    - field_id: nonexistent_field
        YAML

        loader = described_class.new(fixtures_path)
        # Temporarily replace structure file
        allow(loader).to receive(:structure_file_path).and_return(bad_structure)

        expect { loader.load(:test, 2025) }.to raise_error(
          AmsfSurvey::UnknownFieldError, /nonexistent_field/
        )
      ensure
        File.delete(bad_structure) if File.exist?(bad_structure)
      end

      it "raises DuplicateFieldError when field appears twice" do
        dup_structure = File.join(fixtures_path, "dup_structure.yml")
        File.write(dup_structure, <<~YAML)
          sections:
            - title: "Test"
              subsections:
                - title: "Sub 1"
                  questions:
                    - field_id: tgate
                - title: "Sub 2"
                  questions:
                    - field_id: tgate
        YAML

        loader = described_class.new(fixtures_path)
        allow(loader).to receive(:structure_file_path).and_return(dup_structure)

        expect { loader.load(:test, 2025) }.to raise_error(
          AmsfSurvey::DuplicateFieldError, /tgate/
        )
      ensure
        File.delete(dup_structure) if File.exist?(dup_structure)
      end
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/amsf_survey/taxonomy/loader_spec.rb -v`
Expected: FAIL (Loader doesn't use structure file yet)

**Step 3: Rewrite Loader class**

Replace contents of `loader.rb`:

```ruby
# frozen_string_literal: true

module AmsfSurvey
  module Taxonomy
    # Orchestrates parsing of all taxonomy files and builds a Questionnaire.
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

        # Parse structure file and assemble sections
        structure_data = parse_structure
        sections = build_sections(structure_data[:sections], field_index)

        Questionnaire.new(
          industry: industry,
          year: year,
          sections: sections,
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

        Field.new(
          id: field_id,
          type: schema[:type],
          xbrl_type: schema[:xbrl_type],
          label: label_data[:label] || field_id.to_s,
          verbose_label: label_data[:verbose_label],
          valid_values: schema[:valid_values],
          section_id: nil,  # No longer used
          depends_on: depends_on,
          gate: is_gate
        )
      end

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

      def build_sections(sections_data, field_index)
        seen_fields = {}

        sections_data.map do |section_data|
          subsections = section_data[:subsections].map do |sub_data|
            build_subsection(sub_data, field_index, seen_fields, section_data[:title])
          end

          Section.new(
            number: section_data[:number],
            title: section_data[:title],
            subsections: subsections
          )
        end
      end

      def build_subsection(sub_data, field_index, seen_fields, section_title)
        questions = sub_data[:questions].map do |q_data|
          build_question(q_data, field_index, seen_fields, section_title, sub_data[:title])
        end

        Subsection.new(
          number: sub_data[:number],
          title: sub_data[:title],
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

        Question.new(
          number: q_data[:number],
          field: field,
          instructions: q_data[:instructions]
        )
      end
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/amsf_survey/taxonomy/loader_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add amsf_survey/lib/amsf_survey/taxonomy/loader.rb amsf_survey/spec/amsf_survey/taxonomy/loader_spec.rb
git commit -m "refactor: Loader now uses StructureParser for PDF-based structure"
```

---

## Task 7: Update Questionnaire Class

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/questionnaire.rb`
- Rewrite: `amsf_survey/spec/amsf_survey/questionnaire_spec.rb`

**Step 1: Write new tests for updated Questionnaire**

Replace contents of `questionnaire_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe AmsfSurvey::Questionnaire do
  let(:field1) do
    AmsfSurvey::Field.new(
      id: :t001, type: :integer, xbrl_type: "xbrli:integerItemType",
      label: "Field 1", section_id: nil, gate: false
    )
  end

  let(:field2) do
    AmsfSurvey::Field.new(
      id: :t002, type: :string, xbrl_type: "xbrli:stringItemType",
      label: "Field 2", section_id: nil, gate: false
    )
  end

  let(:questions) do
    [
      AmsfSurvey::Question.new(number: 1, field: field1, instructions: nil),
      AmsfSurvey::Question.new(number: 2, field: field2, instructions: nil)
    ]
  end

  let(:subsection) do
    AmsfSurvey::Subsection.new(number: 1, title: "Sub 1", questions: questions)
  end

  let(:section) do
    AmsfSurvey::Section.new(number: 1, title: "Section 1", subsections: [subsection])
  end

  let(:questionnaire) do
    described_class.new(
      industry: :test,
      year: 2025,
      sections: [section],
      taxonomy_namespace: "https://test.example.com"
    )
  end

  describe "#initialize" do
    it "sets industry, year, sections, and taxonomy_namespace" do
      expect(questionnaire.industry).to eq(:test)
      expect(questionnaire.year).to eq(2025)
      expect(questionnaire.sections).to eq([section])
      expect(questionnaire.taxonomy_namespace).to eq("https://test.example.com")
    end
  end

  describe "#questions" do
    it "returns all questions from all sections" do
      expect(questionnaire.questions).to eq(questions)
    end
  end

  describe "#question_count" do
    it "returns total number of questions" do
      expect(questionnaire.question_count).to eq(2)
    end
  end

  describe "#field" do
    it "looks up field by lowercase ID" do
      expect(questionnaire.field(:t001)).to eq(field1)
    end

    it "normalizes lookup to lowercase" do
      expect(questionnaire.field(:T001)).to eq(field1)
      expect(questionnaire.field("T001")).to eq(field1)
    end

    it "returns nil for unknown field" do
      expect(questionnaire.field(:unknown)).to be_nil
    end
  end

  describe "#section_count" do
    it "returns number of sections" do
      expect(questionnaire.section_count).to eq(1)
    end
  end

  describe "#gate_fields" do
    it "returns fields where gate is true" do
      gate_field = AmsfSurvey::Field.new(
        id: :tgate, type: :boolean, xbrl_type: "xbrli:booleanItemType",
        label: "Gate", section_id: nil, gate: true
      )
      gate_question = AmsfSurvey::Question.new(number: 3, field: gate_field, instructions: nil)
      sub_with_gate = AmsfSurvey::Subsection.new(number: 1, title: "Sub", questions: [gate_question])
      section_with_gate = AmsfSurvey::Section.new(number: 1, title: "Sec", subsections: [sub_with_gate])

      q = described_class.new(
        industry: :test, year: 2025, sections: [section_with_gate]
      )

      expect(q.gate_fields).to eq([gate_field])
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/amsf_survey/questionnaire_spec.rb -v`
Expected: FAIL (Questionnaire has old interface)

**Step 3: Update Questionnaire class**

Replace contents of `questionnaire.rb`:

```ruby
# frozen_string_literal: true

module AmsfSurvey
  # Container for an industry/year survey structure.
  # Immutable value object built by the taxonomy loader.
  class Questionnaire
    attr_reader :industry, :year, :sections, :taxonomy_namespace

    def initialize(industry:, year:, sections:, taxonomy_namespace: nil)
      @industry = industry
      @year = year
      @sections = sections
      @taxonomy_namespace = taxonomy_namespace
      @field_index = build_field_index
    end

    # Returns all questions from all sections in order
    def questions
      sections.flat_map(&:questions)
    end

    # Lookup field by lowercase ID
    # Input is normalized to lowercase for consistent lookup
    def field(id)
      @field_index[id.to_s.downcase.to_sym]
    end

    # Total number of questions
    def question_count
      questions.length
    end

    # Number of sections
    def section_count
      sections.length
    end

    # Fields where gate is true
    def gate_fields
      questions.map(&:field).select(&:gate?)
    end

    private

    def build_field_index
      questions.each_with_object({}) do |question, index|
        index[question.id] = question.field
      end
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/amsf_survey/questionnaire_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add amsf_survey/lib/amsf_survey/questionnaire.rb amsf_survey/spec/amsf_survey/questionnaire_spec.rb
git commit -m "refactor: Questionnaire now uses questions instead of fields"
```

---

## Task 8: Update Submission Class

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/submission.rb`
- Modify: `amsf_survey/spec/amsf_survey/submission_spec.rb`

**Step 1: Add tests for unanswered_questions**

Add to `submission_spec.rb`:

```ruby
describe "#unanswered_questions" do
  it "returns Question objects for missing answers" do
    submission[:tgate] = "Oui"
    # t001 is visible but not answered

    unanswered = submission.unanswered_questions
    expect(unanswered).to all(be_a(AmsfSurvey::Question))
    expect(unanswered.map(&:id)).to include(:t001)
  end

  it "excludes answered questions" do
    submission[:tgate] = "Oui"
    submission[:t001] = 42

    unanswered = submission.unanswered_questions
    expect(unanswered.map(&:id)).not_to include(:t001)
  end

  it "excludes invisible questions" do
    submission[:tgate] = "Non"  # Hides t001

    unanswered = submission.unanswered_questions
    expect(unanswered.map(&:id)).not_to include(:t001)
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/amsf_survey/submission_spec.rb -v`
Expected: FAIL (unanswered_questions doesn't exist)

**Step 3: Update Submission class**

Add the `unanswered_questions` method and update `visible_questions` to work with new structure. Replace the relevant methods in `submission.rb`:

```ruby
# Get list of visible questions that are not answered.
# Respects gate visibility - hidden questions are not considered unanswered.
#
# @return [Array<Question>] unanswered questions
def unanswered_questions
  visible_questions.select { |question| question_unanswered?(question) }
end

# Kept for backwards compatibility, delegates to unanswered_questions
def missing_fields
  unanswered_questions.map(&:id)
end

private

# Get all visible questions (gate dependencies satisfied).
def visible_questions
  questionnaire.questions.select { |question| question.visible?(@data) }
end

# Check if a question is unanswered (nil or not set).
def question_unanswered?(question)
  !@data.key?(question.xbrl_id) || @data[question.xbrl_id].nil?
end

# Renamed from visible_fields for internal use
def visible_fields
  visible_questions.map(&:field)
end

# Renamed from field_missing? for internal use
def field_missing?(field)
  !@data.key?(field.xbrl_id) || @data[field.xbrl_id].nil?
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/amsf_survey/submission_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add amsf_survey/lib/amsf_survey/submission.rb amsf_survey/spec/amsf_survey/submission_spec.rb
git commit -m "feat: add unanswered_questions returning Array<Question>"
```

---

## Task 9: Remove PresentationParser

**Files:**
- Delete: `amsf_survey/lib/amsf_survey/taxonomy/presentation_parser.rb`
- Delete: `amsf_survey/spec/amsf_survey/taxonomy/presentation_parser_spec.rb`
- Modify: `amsf_survey/lib/amsf_survey.rb`

**Step 1: Remove require from main module**

Remove this line from `amsf_survey.rb`:

```ruby
require_relative "amsf_survey/taxonomy/presentation_parser"
```

**Step 2: Delete the files**

```bash
rm amsf_survey/lib/amsf_survey/taxonomy/presentation_parser.rb
rm amsf_survey/spec/amsf_survey/taxonomy/presentation_parser_spec.rb
```

**Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor: remove PresentationParser (replaced by StructureParser)"
```

---

## Task 10: Update Integration Tests

**Files:**
- Modify: `amsf_survey/spec/integration/plugin_loading_spec.rb`
- Modify: `amsf_survey/spec/integration/xbrl_generation_spec.rb`
- Modify: `amsf_survey/spec/amsf_survey/integration/submission_validation_spec.rb`

**Step 1: Update integration tests to use new API**

These tests likely reference the old `field_count`, `sections.flat_map(&:fields)` etc. Update them to use `questions`, `question_count`, etc.

Run: `bundle exec rspec spec/integration/ spec/amsf_survey/integration/`

Fix any failures by updating tests to match new API.

**Step 2: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass (322 examples)

**Step 3: Commit**

```bash
git add -A
git commit -m "test: update integration tests for new questionnaire structure"
```

---

## Task 11: Update Field Class (Remove section_id)

**Files:**
- Modify: `amsf_survey/lib/amsf_survey/field.rb`
- Modify: `amsf_survey/spec/amsf_survey/field_spec.rb`

**Step 1: Remove section_id from Field**

The `section_id` attribute is no longer meaningful since questions now belong to Subsections. Remove it from `Field`.

In `field.rb`, remove `:section_id` from `attr_reader` and the `initialize` parameter.

In `field_spec.rb`, remove any references to `section_id` in tests.

**Step 2: Run tests**

Run: `bundle exec rspec spec/amsf_survey/field_spec.rb -v`
Expected: PASS

**Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 4: Commit**

```bash
git add amsf_survey/lib/amsf_survey/field.rb amsf_survey/spec/amsf_survey/field_spec.rb
git commit -m "refactor: remove section_id from Field (no longer needed)"
```

---

## Task 12: Final Verification

**Step 1: Run full test suite with coverage**

Run: `bundle exec rspec`
Expected: All tests pass, 100% line coverage maintained

**Step 2: Run rubocop (if configured)**

Run: `bundle exec rubocop` (if available)
Expected: No new offenses

**Step 3: Manual verification**

Test the new API in console:

```ruby
require 'amsf_survey'
AmsfSurvey.register_plugin(industry: :test, taxonomy_path: "spec/fixtures/taxonomies")
q = AmsfSurvey.questionnaire(industry: :test, year: 2025)

q.sections.each do |s|
  puts "Section #{s.number}: #{s.title}"
  s.subsections.each do |sub|
    puts "  #{sub.number}. #{sub.title}"
    sub.questions.each do |q|
      puts "    Q#{q.number}: #{q.label[0..40]}..."
    end
  end
end
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete questionnaire structure refactoring"
```

---

Plan complete and saved to `docs/plans/2026-01-26-questionnaire-structure-implementation.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
