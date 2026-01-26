# Questionnaire Structure Design

Replace XBRL-based presentation structure with human-readable PDF structure.

## Problem

The XBRL taxonomy organizes fields into 3 dimensional sections (`Link_NoCountryDimension`, `Link_aAC`, `Link_aLE`) that have no meaning to consumers. The PDF questionnaire has a different structure with logical sections, subsections, and question numbering that users expect.

## Solution

Add a `questionnaire_structure.yml` mapping file that defines the PDF structure. The gem exposes this structure through the public API, with questions wrapping XBRL fields.

## Public API

```ruby
questionnaire = AmsfSurvey.questionnaire(industry: :real_estate, year: 2025)

questionnaire.sections.each do |section|
  # section.number => 1, 2, 3
  # section.title  => "Inherent Risk", "Controls", "Signatories"

  section.subsections.each do |subsection|
    # subsection.number => 1, 2, 3... (within section)
    # subsection.title  => "Soumis à la loi n° 1.362"

    subsection.questions.each do |question|
      # question.number       => 1-215, 1-105, or 1-3 (scoped to section)
      # question.instructions => from mapping file (or nil)
      # question.label        => from XBRL
      # question.type         => :boolean, :integer, etc.
      # question.valid_values => ["Oui", "Non"], etc.
      # question.visible?(submission) => gate logic
    end
  end
end

# Direct field lookup
questionnaire.field(:aactive)

# Submission integration
submission.complete?
submission.unanswered_questions  # => Array<Question>
submission.completion_percentage
```

## Data Model

```ruby
class Section
  attr_reader :number,      # Integer: 1, 2, 3
              :title,       # String: "Inherent Risk"
              :subsections  # Array<Subsection>
end

class Subsection
  attr_reader :number,    # Integer: position within section
              :title,     # String: "Soumis à la loi n° 1.362"
              :questions  # Array<Question>
end

class Question
  attr_reader :number,       # Integer: scoped to top section (1-215, 1-105, 1-3)
              :instructions  # String or nil

  # Delegates to underlying Field:
  delegate :id, :label, :verbose_label, :type,
           :valid_values, :xbrl_id, to: :field

  def visible?(submission)
    # Gate logic via field
  end
end

class Field
  # Unchanged - holds XBRL data
end
```

## Mapping File Format

Location: `taxonomies/{industry}/{year}/questionnaire_structure.yml`

```yaml
sections:
  - title: "Inherent Risk"
    subsections:
      - title: "Soumis à la loi n° 1.362"
        questions:
          - field_id: aactive
            instructions: |
              Activités soumises : L'achat, la vente et la location
              de biens immobiliers.
              Pour la location, uniquement les loyers mensuels
              supérieur ou égal à 10.000€
          - field_id: aactiveps
          - field_id: aactiverentals

      - title: "Récapitulatif des clients"
        questions:
          - field_id: a1101
            instructions: |
              L'expression « clients uniques » signifie que...
          - field_id: a1102

  - title: "Controls"
    subsections:
      # ...

  - title: "Signatories"
    subsections:
      # ...
```

Numbers are derived from position:
- Section numbers: 1, 2, 3 based on order in file
- Subsection numbers: 1, 2, 3... within each section
- Question numbers: 1, 2, 3... scoped to top section (restarts per section)

## Loading & Assembly

```
┌─────────────────────────────────────────────────────────────┐
│                     Taxonomy::Loader                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Parse XBRL files (existing)                             │
│     └── SchemaParser  → field types, valid_values           │
│     └── LabelParser   → labels, verbose_labels              │
│     └── XuleParser    → gate dependencies                   │
│                                                             │
│  2. Parse structure file (new)                              │
│     └── StructureParser → sections, subsections, questions  │
│                                                             │
│  3. Assemble Questionnaire                                  │
│     └── For each question in structure:                     │
│         └── Look up Field by field_id                       │
│         └── Create Question wrapping Field + instructions   │
│     └── Build Section/Subsection hierarchy                  │
│     └── Assign numbers based on position                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Missing structure file | Raise `MissingStructureFileError` |
| Invalid field_id in YAML | Raise `UnknownFieldError` with ID and location |
| Duplicate field_id in YAML | Raise `DuplicateFieldError` |
| XBRL fields not in YAML | Silent (many are dimensional/internal) |
| Empty instructions | `question.instructions` returns `nil` |

## Code Changes

**New classes:**
- `Subsection` - holds number, title, questions
- `Question` - wraps Field, adds number and instructions
- `Taxonomy::StructureParser` - parses questionnaire_structure.yml

**Changed classes:**
- `Section` - repurposed from XBRL to PDF structure (title, subsections)
- `Questionnaire` - sections now returns PDF structure; add field index for direct lookup
- `Taxonomy::Loader` - calls StructureParser, assembles Question objects
- `Submission` - `unanswered_questions` returns Array<Question>

**Removed:**
- `Taxonomy::PresentationParser` - XBRL presentation no longer used

## PDF Structure Reference

| Section | Title | Questions |
|---------|-------|-----------|
| 1 | Inherent Risk | 215 (Q1-Q215) |
| 2 | Controls | 105 (Q1-Q105) |
| 3 | Signatories | 3 (Q1-Q3) |

Each section contains multiple subsections (1.1, 1.2, 2.1, etc.) with their own titles.
