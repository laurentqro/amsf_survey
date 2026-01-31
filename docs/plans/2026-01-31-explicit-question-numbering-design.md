# Explicit Question Numbering with Parts - Design

## Overview

Replace implicit question ordering in `questionnaire_structure.yml` with explicit numbering and add a `Part` layer to match the PDF hierarchy.

## Current State

```yaml
sections:
  - title: "Customer Risk"
    subsections:
      - title: "Active in Reporting Cycle"
        questions:
          - field_id: "aACTIVE"
            instructions: "..."
```

3-level hierarchy: Section → Subsection → Question

## Target State

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
                instructions: "..."
```

4-level hierarchy: Part → Section → Subsection → Question

## Structure Details

### Parts

| Name | Sections | Questions |
|------|----------|-----------|
| Inherent Risk | 1-3 (Customer Risk, Products & Services Risk, Distribution Risk) | Q1-Q215 |
| Controls | 4 (Controls) | Q1-Q105 |
| Signatories | 5 (Signatories) | Q1-Q3 |

**Total:** 323 questions

### Numbering Rules

- **Section numbers:** Global (1-5)
- **Subsection numbers:** Follow section prefix (1.1, 1.2, ..., 2.1, 2.2, ..., 5.1)
- **Question numbers:** Reset to 1 at each Part boundary

### YAML Schema

```yaml
parts:
  - name: string              # "Inherent Risk", "Controls", "Signatories"
    sections:
      - number: integer       # 1, 2, 3, 4, 5
        title: string
        instructions: string | null  # Optional section-level instructions
        subsections:
          - number: string    # "1.1", "1.2", etc.
            title: string
            instructions: string | null  # Optional subsection-level instructions
            questions:
              - field_id: string
                question_number: integer  # Resets per Part
                instructions: string | null
```

## Use Cases

1. **API consumption:** Display "Inherent Risk - Q37" in consumer apps
2. **PDF cross-referencing:** Trace YAML entries to PDF questions
3. **Validation:** Verify question counts per part (215 + 105 + 3 = 323)
4. **Debugging:** Immediately identify which PDF question a field represents

## Model Changes

### New Class: Part

```ruby
class Part
  attr_reader :name, :sections

  def questions
    sections.flat_map(&:questions)
  end
end
```

### Updated: Questionnaire

```ruby
class Questionnaire
  attr_reader :parts  # New: array of Part objects

  def sections
    parts.flat_map(&:sections)  # Backward compatible
  end
end
```

### Updated: Section

```ruby
class Section
  attr_reader :number, :title, :subsections, :part  # Add number, part reference
end
```

### Updated: Subsection

```ruby
class Subsection
  attr_reader :number, :title, :questions  # Add number
end
```

### Updated: Question

```ruby
class Question
  attr_reader :question_number  # New field
end
```

## Parser Changes

`StructureParser` must handle the new `parts` top-level key and extract:
- Part name
- Section number
- Subsection number
- Question number

## View Example (Rails)

```erb
<%= part.name %> - Q<%= question.question_number %>: <%= question.label %>
```

Output: "Inherent Risk - Q37: Does the entity provide services to..."
