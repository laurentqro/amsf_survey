# Research: XBRL Generator

**Feature Branch**: `004-xbrl-generator`
**Created**: 2025-12-22

## Research Questions

### 1. XBRL Instance Document Structure

**Question**: What is the required structure for an XBRL 2.1 instance document compatible with Strix portal?

**Findings**:

The XBRL 2.1 instance document requires:

1. **XML Declaration**: `<?xml version="1.0" encoding="UTF-8"?>`

2. **Root Element**: `<xbrli:xbrl>` with namespace declarations

3. **Required Namespaces**:
   - `xmlns:xbrli="http://www.xbrl.org/2003/instance"` - XBRL instance namespace
   - `xmlns:link="http://www.xbrl.org/2003/linkbase"` - Linkbase namespace
   - `xmlns:xlink="http://www.w3.org/1999/xlink"` - XLink namespace
   - `xmlns:strix="{taxonomy_namespace}"` - Taxonomy-specific namespace

4. **Context Element**: Required for all facts
   - Must have unique `id` attribute
   - Contains `<xbrli:entity>` with identifier
   - Contains `<xbrli:period>` with instant date

5. **Fact Elements**: One per field value
   - Element name is the XBRL code (e.g., `strix:a1101`)
   - `contextRef` attribute references context id
   - `decimals` attribute for numeric types
   - Content is the formatted value

**Decision**: Follow XBRL 2.1 specification with instant period (single date, not duration).

**Rationale**: Strix portal uses instant periods for annual survey submissions.

---

### 2. Taxonomy Namespace Pattern

**Question**: How should the taxonomy namespace be constructed from industry and year?

**Findings**:

From the real estate taxonomy XSD:
```
targetNamespace="https://amlcft.amsf.mc/dcm/DTS/strix_Real_Estate_AML_CFT_survey_2025/fr"
```

Pattern analysis:
- Base URL: `https://amlcft.amsf.mc/dcm/DTS/`
- Survey identifier: `strix_{Industry}_AML_CFT_survey_{Year}`
- Locale suffix: `/fr`

For `:real_estate` and `2025`:
- Industry string: `Real_Estate` (title case with underscore)
- Result: `https://amlcft.amsf.mc/dcm/DTS/strix_Real_Estate_AML_CFT_survey_2025/fr`

**Decision**: Store taxonomy namespace in semantic_mappings.yml or derive from XSD `targetNamespace` at load time.

**Rationale**: The namespace is already defined in the XSD. Extracting it during taxonomy loading ensures consistency and avoids hard-coding industry-specific patterns in the core gem.

**Implementation Note**: Add `taxonomy_namespace` to Questionnaire during loading, read from XSD's `targetNamespace`.

---

### 3. Decimal Precision for Numeric Types

**Question**: What `decimals` attribute values are required for different field types?

**Findings**:

XBRL decimals attribute meaning:
- `decimals="0"` - Integer precision (no decimal places)
- `decimals="2"` - Two decimal places (monetary)
- `decimals="INF"` - Infinite precision (exact value)

Field type mapping:
| Field Type | `decimals` Value | Rationale |
|------------|------------------|-----------|
| `:integer` | `0` | Whole numbers |
| `:monetary` | `2` | Euro amounts (2 decimal places) |
| `:percentage` | `2` | Percentages with decimal precision |
| `:boolean` | (omit) | Non-numeric, no decimals attribute |
| `:string` | (omit) | Non-numeric, no decimals attribute |
| `:enum` | (omit) | Non-numeric, no decimals attribute |

**Decision**: Use `decimals="0"` for integers, `decimals="2"` for monetary/percentage, omit for non-numeric.

**Rationale**: Matches XBRL best practices and regulatory expectations.

---

### 4. Boolean Value Representation

**Question**: How should boolean values be represented in XBRL output?

**Findings**:

The taxonomy uses French values:
- `true` → `"Oui"`
- `false` → `"Non"`

The TypeCaster stores booleans as Ruby `true`/`false` internally.

**Decision**: Convert Ruby booleans back to French strings during XBRL generation.

**Rationale**: The Strix portal expects the original French values from the taxonomy. This is a presentation concern, not a storage concern.

**Implementation Note**: Add `format_for_xbrl(value)` method to handle boolean → French conversion.

---

### 5. Entity Identifier Scheme

**Question**: What scheme URI should be used for the entity identifier?

**Findings**:

XBRL entity identifier format:
```xml
<xbrli:entity>
  <xbrli:identifier scheme="{scheme_uri}">{entity_id}</xbrli:identifier>
</xbrli:entity>
```

For Monaco AMSF submissions, the scheme should reflect the regulatory authority.

**Decision**: Use `https://amlcft.amsf.mc` as the default scheme URI.

**Rationale**: This matches the AMSF domain used in the taxonomy namespace. Can be made configurable if needed.

---

### 6. Nokogiri XML Builder Pattern

**Question**: What's the best approach for building XML with Nokogiri?

**Findings**:

Nokogiri offers two approaches:
1. **Builder DSL**: Clean Ruby syntax, good for simple documents
2. **Direct node creation**: More control, better for complex namespaces

For XBRL with multiple namespaces, the Builder DSL with namespace support works well:

```ruby
builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
  xml.xbrl('xmlns:xbrli' => XBRLI_NS, 'xmlns:strix' => taxonomy_ns) do
    xml['xbrli'].context(id: 'ctx') do
      # ...
    end
    xml['strix'].a1101(contextRef: 'ctx', decimals: '0') { xml.text '50' }
  end
end
builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
```

**Decision**: Use Nokogiri Builder DSL with explicit namespace prefixes.

**Rationale**: Already using Nokogiri for parsing. Builder DSL is readable and handles escaping automatically.

---

### 7. Pretty Print vs Minified Output

**Question**: How to implement pretty printing toggle?

**Findings**:

Nokogiri's `to_xml` accepts `SaveOptions`:
- Default (no options): Minified output
- `SaveOptions::FORMAT`: Indented, pretty-printed output

```ruby
# Minified
doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)

# Pretty
doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::FORMAT |
                      Nokogiri::XML::Node::SaveOptions::AS_XML)
```

**Decision**: Default to minified, use `pretty: true` option for formatted output.

**Rationale**: Minified is more efficient for transmission. Pretty is useful for debugging.

---

## Alternatives Considered

### XML Library Choice

| Option | Pros | Cons |
|--------|------|------|
| Nokogiri Builder | Already in deps, handles namespaces well | Slightly verbose for complex XML |
| ERB template | Simple, readable | Harder to manage namespaces, escaping |
| REXML | Stdlib, no gem | Slower, less namespace support |
| Ox | Fast | Another dependency |

**Chosen**: Nokogiri Builder - already a dependency, proven namespace handling.

### Namespace Storage

| Option | Pros | Cons |
|--------|------|------|
| Hard-coded pattern | Simple | Brittle if taxonomy format changes |
| Extract from XSD | Single source of truth | Requires XSD parsing enhancement |
| Store in semantic_mappings.yml | Explicit, configurable | Manual maintenance |

**Chosen**: Extract from XSD during taxonomy loading - maintains taxonomy as source of truth per constitution.

---

## Dependencies

- **Nokogiri** (existing): XML generation with Builder DSL
- No new dependencies required

---

## Outstanding Questions

None - all technical questions resolved.
