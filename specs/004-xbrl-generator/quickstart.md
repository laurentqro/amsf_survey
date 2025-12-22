# Quickstart: XBRL Generator

**Feature Branch**: `004-xbrl-generator`
**Created**: 2025-12-22

## Overview

Generate XBRL instance XML documents from validated survey submissions for upload to the Monaco AMSF Strix portal.

## Basic Usage

```ruby
require "amsf_survey"
require "amsf_survey/real_estate"  # Load industry plugin

# 1. Create and populate a submission
submission = AmsfSurvey.build_submission(
  industry: :real_estate,
  year: 2025,
  entity_id: "ENTITY_001",
  period: Date.new(2025, 12, 31)
)

# Set field values
submission[:has_activity] = true
submission[:total_clients] = 150
submission[:national_individuals] = 100
submission[:foreign_residents] = 50

# 2. Validate (recommended)
result = AmsfSurvey.validate(submission)
if result.valid?
  # 3. Generate XBRL
  xml = AmsfSurvey.to_xbrl(submission)

  # 4. Save to file or upload to Strix
  File.write("submission_2025.xml", xml)
end
```

## Output Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xbrli:xbrl
  xmlns:xbrli="http://www.xbrl.org/2003/instance"
  xmlns:link="http://www.xbrl.org/2003/linkbase"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  xmlns:strix="https://amlcft.amsf.mc/dcm/DTS/strix_Real_Estate_AML_CFT_survey_2025/fr">

  <link:schemaRef
    xlink:type="simple"
    xlink:href="strix_Real_Estate_AML_CFT_survey_2025.xsd"/>

  <xbrli:context id="ctx_2025">
    <xbrli:entity>
      <xbrli:identifier scheme="https://amlcft.amsf.mc">ENTITY_001</xbrli:identifier>
    </xbrli:entity>
    <xbrli:period>
      <xbrli:instant>2025-12-31</xbrli:instant>
    </xbrli:period>
  </xbrli:context>

  <strix:aACTIVEPS contextRef="ctx_2025">Oui</strix:aACTIVEPS>
  <strix:a1101 contextRef="ctx_2025" decimals="0">150</strix:a1101>
  <strix:a1102 contextRef="ctx_2025" decimals="0">100</strix:a1102>
  <strix:a1103 contextRef="ctx_2025" decimals="0">50</strix:a1103>

</xbrli:xbrl>
```

## Generation Options

### Pretty Printing

```ruby
# Default: minified (single line, no indentation)
xml = AmsfSurvey.to_xbrl(submission)

# Pretty: indented, human-readable
xml = AmsfSurvey.to_xbrl(submission, pretty: true)
```

### Empty Field Handling

```ruby
# Default: include empty fields with empty content
xml = AmsfSurvey.to_xbrl(submission, include_empty: true)

# Exclude: omit fields with nil values
xml = AmsfSurvey.to_xbrl(submission, include_empty: false)
```

### Combined Options

```ruby
xml = AmsfSurvey.to_xbrl(submission, pretty: true, include_empty: false)
```

## Field Type Formatting

| Type | Ruby Value | XBRL Output |
|------|------------|-------------|
| Boolean | `true` | `Oui` |
| Boolean | `false` | `Non` |
| Integer | `150` | `150` (decimals="0") |
| Monetary | `1234.56` | `1234.56` (decimals="2") |
| Percentage | `75.5` | `75.50` (decimals="2") |
| String | `"text"` | `text` |
| Enum | `"Value"` | `Value` |

## Gate Visibility

Fields hidden by gate questions are automatically excluded:

```ruby
# If has_rental_activity is false, rental-related fields are hidden
submission[:has_rental_activity] = false
submission[:rental_transaction_count] = 10  # This value exists but...

xml = AmsfSurvey.to_xbrl(submission)
# rental_transaction_count will NOT appear in the XML output
# because it's controlled by the has_rental_activity gate
```

## Error Handling

```ruby
begin
  xml = AmsfSurvey.to_xbrl(submission)
rescue AmsfSurvey::GenerationError => e
  # Handle generation errors (e.g., missing required data)
  puts "Generation failed: #{e.message}"
end
```

## Workflow Integration

### Typical Flow

```ruby
# 1. Build submission
submission = AmsfSurvey.build_submission(...)

# 2. Populate from form/API data
params.each { |k, v| submission[k.to_sym] = v }

# 3. Check completeness
unless submission.complete?
  puts "Missing: #{submission.missing_fields.join(', ')}"
end

# 4. Validate
result = AmsfSurvey.validate(submission)
unless result.valid?
  result.errors.each { |e| puts "#{e.field}: #{e.message}" }
end

# 5. Generate only if valid
xml = AmsfSurvey.to_xbrl(submission) if result.valid?

# 6. Upload to Strix portal
StrixClient.upload(xml) if xml
```

### Preview Mode

Generate XBRL before validation is complete (for preview purposes):

```ruby
# Generate even with missing/invalid data
# Caller accepts responsibility for incomplete output
xml = AmsfSurvey.to_xbrl(submission)
```

## Testing

```ruby
RSpec.describe "XBRL Generation" do
  let(:submission) do
    AmsfSurvey.build_submission(
      industry: :real_estate,
      year: 2025,
      entity_id: "TEST_001",
      period: Date.new(2025, 12, 31)
    )
  end

  it "generates valid XML" do
    submission[:has_activity] = true
    submission[:total_clients] = 10

    xml = AmsfSurvey.to_xbrl(submission)

    doc = Nokogiri::XML(xml)
    expect(doc.errors).to be_empty
    expect(doc.at_xpath('//strix:a1101', strix: taxonomy_ns).text).to eq('10')
  end
end
```
