# frozen_string_literal: true

require "nokogiri"
require "bigdecimal"
require "uri"

module AmsfSurvey
  # Generates XBRL instance XML documents from validated Submission objects.
  #
  # The Generator transforms survey response data into XBRL 2.1 format
  # compatible with the Monaco AMSF Strix portal.
  #
  # XBRL Document Structure:
  #   xbrli:xbrl (root)
  #     ├── link:schemaRef (taxonomy reference)
  #     ├── xbrli:context (entity + period metadata)
  #     ├── xbrli:unit (for numeric facts)
  #     └── strix:* facts (one element per field)
  #
  # @example Basic usage
  #   generator = Generator.new(submission)
  #   xml = generator.generate
  #
  # @example With options
  #   generator = Generator.new(submission, pretty: true, include_empty: false)
  #   xml = generator.generate
  #
  class Generator
    # Standard XBRL namespace URIs (XBRL 2.1 specification)
    XBRLI_NS = "http://www.xbrl.org/2003/instance"
    LINK_NS = "http://www.xbrl.org/2003/linkbase"
    XLINK_NS = "http://www.w3.org/1999/xlink"
    XBRLDI_NS = "http://xbrl.org/2006/xbrldi"
    XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"

    # Entity identifier scheme for Monaco AMSF (matches regulatory requirements)
    ENTITY_SCHEME = "https://amlcft.amsf.mc"

    # Unit ID for dimensionless numeric values (counts, percentages as ratios)
    PURE_UNIT_ID = "pure"

    # Unit ID for monetary values (ISO 4217 currency code)
    MONETARY_UNIT_ID = "EUR"

    # ISO 4217 namespace for currency codes
    ISO4217_NS = "http://www.xbrl.org/2003/iso4217"

    # Default dimension name (fallback if not parsed from taxonomy)
    DEFAULT_DIMENSION_NAME = "CountryDimension"

    # Default member prefix (fallback if not parsed from taxonomy)
    DEFAULT_MEMBER_PREFIX = "sdl"

    # @param submission [Submission] the source submission object
    # @param options [Hash] generation options
    # @option options [Boolean] :pretty (false) output indented XML
    # @option options [Boolean] :include_empty (true) include empty facts for nil values
    def initialize(submission, options = {})
      @submission = submission
      @pretty = options.fetch(:pretty, false)
      @include_empty = options.fetch(:include_empty, true)
      @dimensional_contexts = {}
    end

    # Generate XBRL instance XML from the submission.
    #
    # @return [String] the XBRL instance XML
    # @raise [GeneratorError] if submission is invalid for generation
    def generate
      validate_submission!
      doc = build_document
      format_output(doc)
    end

    private

    attr_reader :submission

    # Validate that submission has required data for XBRL generation.
    # Fails fast with clear error messages for common misconfigurations.
    #
    # @raise [GeneratorError] if validation fails
    def validate_submission!
      raise GeneratorError, "Submission cannot be nil" if submission.nil?

      unless submission.period.respond_to?(:strftime)
        raise GeneratorError, "Submission period must be a Date object, got: #{submission.period.class}"
      end

      if submission.questionnaire.nil?
        raise GeneratorError, "Submission questionnaire is not available. " \
                              "Ensure the industry is registered and year is supported."
      end
    end

    # Questionnaire provides field metadata and taxonomy namespace
    def questionnaire
      @questionnaire ||= submission.questionnaire
    end

    # The taxonomy namespace from the XSD (e.g., https://amlcft.amsf.mc/dcm/DTS/strix_...)
    def taxonomy_namespace
      questionnaire.taxonomy_namespace
    end

    # The dimension name from the taxonomy (e.g., "CountryDimension")
    # Falls back to default if not parsed from _def.xml
    def dimension_name
      questionnaire.dimension_name || DEFAULT_DIMENSION_NAME
    end

    # The member prefix from the taxonomy (e.g., "sdl")
    # Falls back to default if not parsed from _def.xml
    def member_prefix
      questionnaire.member_prefix || DEFAULT_MEMBER_PREFIX
    end

    # Generate a unique context ID for this submission.
    # Includes entity_id and full date to ensure uniqueness if multiple
    # submissions are ever combined in a single XBRL document.
    # Uses YYYYMMDD format for period to handle multiple reporting periods per year.
    def context_id
      @context_id ||= "ctx_#{submission.entity_id}_#{submission.period.strftime('%Y%m%d')}"
    end

    # Build the XBRL document using direct Nokogiri node creation
    def build_document
      doc = Nokogiri::XML::Document.new
      doc.encoding = "UTF-8"

      # Reset caches for this document generation
      @dimensional_contexts.clear
      @base_context = nil

      # Create root element with namespaces
      root = Nokogiri::XML::Node.new("xbrl", doc)
      root.add_namespace_definition("xbrli", XBRLI_NS)
      root.add_namespace_definition("link", LINK_NS)
      root.add_namespace_definition("xlink", XLINK_NS)
      root.add_namespace_definition("xbrldi", XBRLDI_NS)
      root.add_namespace_definition("iso4217", ISO4217_NS)
      root.add_namespace_definition("xsi", XSI_NS)
      root.add_namespace_definition("strix", taxonomy_namespace)
      root.namespace = root.namespace_definitions.find { |ns| ns.prefix == "xbrli" }

      doc.root = root

      # Build child elements
      build_schema_ref(doc, root)
      build_context(doc, root)
      build_units(doc, root)
      build_facts(doc, root)

      doc
    end

    # Build the schemaRef element
    def build_schema_ref(doc, parent)
      schema_ref = Nokogiri::XML::Node.new("schemaRef", doc)
      schema_ref.namespace = parent.namespace_definitions.find { |ns| ns.prefix == "link" }
      schema_ref["xlink:type"] = "simple"
      schema_ref["xlink:href"] = schema_href
      parent.add_child(schema_ref)
    end

    # Determine the schema href for schemaRef element.
    # Prefers explicit schema_url from taxonomy.yml if available,
    # otherwise falls back to extracting filename from taxonomy_namespace.
    #
    # @return [String] the schema URL or filename
    def schema_href
      questionnaire.schema_url || extract_schema_filename
    end

    # Extract schema filename from taxonomy namespace.
    # Handles edge cases like query parameters, trailing slashes, and fragments.
    # Falls back to "taxonomy.xsd" if namespace is nil, empty, or malformed.
    #
    # @return [String] the XSD filename (e.g., "test_industry_2025.xsd")
    def extract_schema_filename
      return "taxonomy.xsd" if taxonomy_namespace.nil? || taxonomy_namespace.to_s.empty?

      uri = URI.parse(taxonomy_namespace.to_s)
      basename = File.basename(uri.path)
      # File.basename("/") returns "/" which we treat as empty
      (basename.empty? || basename == "/") ? "taxonomy.xsd" : "#{basename}.xsd"
    rescue URI::InvalidURIError
      "taxonomy.xsd"
    end

    # Build the XBRL context element with entity and period
    def build_context(doc, parent)
      xbrli_ns = parent.namespace_definitions.find { |ns| ns.prefix == "xbrli" }

      # Context element
      context = Nokogiri::XML::Node.new("context", doc)
      context.namespace = xbrli_ns
      context["id"] = context_id

      # Entity element
      entity = Nokogiri::XML::Node.new("entity", doc)
      entity.namespace = xbrli_ns

      # Identifier element
      identifier = Nokogiri::XML::Node.new("identifier", doc)
      identifier.namespace = xbrli_ns
      identifier["scheme"] = ENTITY_SCHEME
      identifier.content = submission.entity_id

      entity.add_child(identifier)
      context.add_child(entity)

      # Period element
      period = Nokogiri::XML::Node.new("period", doc)
      period.namespace = xbrli_ns

      # Instant element
      instant = Nokogiri::XML::Node.new("instant", doc)
      instant.namespace = xbrli_ns
      instant.content = format_date(submission.period)

      period.add_child(instant)
      context.add_child(period)

      parent.add_child(context)
    end

    # Build XBRL unit elements for numeric facts.
    # Creates both pure unit (for counts, integers, percentages) and
    # monetary unit (for currency values).
    def build_units(doc, parent)
      build_pure_unit(doc, parent)
      build_monetary_unit(doc, parent)
    end

    # Build the pure unit for dimensionless numeric values
    def build_pure_unit(doc, parent)
      xbrli_ns = parent.namespace_definitions.find { |ns| ns.prefix == "xbrli" }

      unit = Nokogiri::XML::Node.new("unit", doc)
      unit.namespace = xbrli_ns
      unit["id"] = PURE_UNIT_ID

      measure = Nokogiri::XML::Node.new("measure", doc)
      measure.namespace = xbrli_ns
      measure.content = "xbrli:pure"

      unit.add_child(measure)
      parent.add_child(unit)
    end

    # Build the monetary unit for currency values (EUR)
    def build_monetary_unit(doc, parent)
      xbrli_ns = parent.namespace_definitions.find { |ns| ns.prefix == "xbrli" }

      unit = Nokogiri::XML::Node.new("unit", doc)
      unit.namespace = xbrli_ns
      unit["id"] = MONETARY_UNIT_ID

      measure = Nokogiri::XML::Node.new("measure", doc)
      measure.namespace = xbrli_ns
      measure.content = "iso4217:EUR"

      unit.add_child(measure)
      parent.add_child(unit)
    end

    # Build fact elements for all visible questions
    def build_facts(doc, parent)
      data = submission.data
      strix_ns = parent.namespace_definitions.find { |ns| ns.prefix == "strix" }

      questionnaire.questions.each do |question|
        next unless question.visible?(data)

        # Use xbrl_id for data lookup (internal storage uses XBRL IDs)
        value = data[question.xbrl_id]

        # Skip nil/empty values if include_empty is false
        # Empty hashes for dimensional fields are treated as unanswered
        next if empty_value?(value) && !@include_empty

        # Validate dimensional field values
        if question.dimensional?
          validate_dimensional_value!(question, value)
          # Skip nil - can't build facts without data. Arelle validates completeness.
          build_dimensional_facts(doc, parent, strix_ns, question, value) if value
        else
          # Non-dimensional fields should not receive Hash values
          if value.is_a?(Hash)
            raise GeneratorError, "Non-dimensional field '#{question.xbrl_id}' received Hash value. " \
                                  "Only dimensional fields accept country breakdown data."
          end
          build_fact(doc, parent, strix_ns, question, value)
        end
      end
    end

    # Build a single fact element
    def build_fact(doc, parent, strix_ns, question, value)
      build_fact_element(doc, parent, strix_ns, question, value, context_id)
    end

    # Build dimensional facts - one fact per dimension member (e.g., per country)
    #
    # @param doc [Nokogiri::XML::Document] the XML document
    # @param parent [Nokogiri::XML::Node] the parent element
    # @param strix_ns [Nokogiri::XML::Namespace] the strix namespace
    # @param question [Question] the question being processed
    # @param values [Hash] country code => value mapping (e.g., {"RU" => 9.0, "FR" => 5.0})
    def build_dimensional_facts(doc, parent, strix_ns, question, values)
      values.each do |country_code, value|
        next if value.nil? && !@include_empty

        # Ensure dimensional context exists for this country
        dim_context_id = ensure_dimensional_context(doc, parent, country_code)

        # Build fact referencing the dimensional context
        build_dimensional_fact(doc, parent, strix_ns, question, value, dim_context_id)
      end
    end

    # Ensure a dimensional context exists for the given country, creating if needed.
    # Dimensional contexts are lazily created and cached to avoid duplicates.
    #
    # @param doc [Nokogiri::XML::Document] the XML document
    # @param parent [Nokogiri::XML::Node] the root element to add context to
    # @param country_code [String] ISO country code (e.g., "RU", "FR")
    # @return [String] the dimensional context ID
    def ensure_dimensional_context(doc, parent, country_code)
      cache_key = country_code.to_s.upcase

      return @dimensional_contexts[cache_key] if @dimensional_contexts[cache_key]

      dim_context_id = build_dimensional_context(doc, parent, cache_key)
      @dimensional_contexts[cache_key] = dim_context_id
      dim_context_id
    end

    # Get the base context node, caching the XPath lookup for performance.
    # Called once per country when building dimensional contexts.
    #
    # @param parent [Nokogiri::XML::Node] the root element
    # @return [Nokogiri::XML::Node] the base context element
    # @raise [GeneratorError] if base context doesn't exist
    def cached_base_context(parent)
      @base_context ||= begin
        ctx = parent.at_xpath("xbrli:context", "xbrli" => XBRLI_NS)
        raise GeneratorError, "Base context must exist before creating dimensional contexts" unless ctx
        ctx
      end
    end

    # Build a dimensional context with country segment
    #
    # @param doc [Nokogiri::XML::Document] the XML document
    # @param parent [Nokogiri::XML::Node] the root element
    # @param country_code [String] ISO country code (uppercase)
    # @return [String] the created context ID
    def build_dimensional_context(doc, parent, country_code)
      xbrli_ns = parent.namespace_definitions.find { |ns| ns.prefix == "xbrli" }
      xbrldi_ns = parent.namespace_definitions.find { |ns| ns.prefix == "xbrldi" }
      strix_ns = parent.namespace_definitions.find { |ns| ns.prefix == "strix" }

      dim_context_id = "#{context_id}_#{country_code}"

      # Context element
      context = Nokogiri::XML::Node.new("context", doc)
      context.namespace = xbrli_ns
      context["id"] = dim_context_id

      # Entity element with segment for dimension
      entity = Nokogiri::XML::Node.new("entity", doc)
      entity.namespace = xbrli_ns

      # Identifier element
      identifier = Nokogiri::XML::Node.new("identifier", doc)
      identifier.namespace = xbrli_ns
      identifier["scheme"] = ENTITY_SCHEME
      identifier.content = submission.entity_id
      entity.add_child(identifier)

      # Segment element containing the dimension member
      segment = Nokogiri::XML::Node.new("segment", doc)
      segment.namespace = xbrli_ns

      # Explicit dimension member
      explicit_member = Nokogiri::XML::Node.new("explicitMember", doc)
      explicit_member.namespace = xbrldi_ns
      explicit_member["dimension"] = "strix:#{dimension_name}"
      explicit_member.content = "strix:#{member_prefix}#{country_code}"

      segment.add_child(explicit_member)
      entity.add_child(segment)
      context.add_child(entity)

      # Period element
      period = Nokogiri::XML::Node.new("period", doc)
      period.namespace = xbrli_ns

      instant = Nokogiri::XML::Node.new("instant", doc)
      instant.namespace = xbrli_ns
      instant.content = format_date(submission.period)

      period.add_child(instant)
      context.add_child(period)

      # Insert dimensional context after the base context.
      # Base context must exist (created by build_context before build_facts).
      base_context = cached_base_context(parent)
      base_context.add_next_sibling(context)

      dim_context_id
    end

    # Build a single dimensional fact
    def build_dimensional_fact(doc, parent, strix_ns, question, value, dim_context_id)
      build_fact_element(doc, parent, strix_ns, question, value, dim_context_id)
    end

    # Build a fact element with the specified context reference.
    # Common implementation for both regular and dimensional facts.
    #
    # @param doc [Nokogiri::XML::Document] the XML document
    # @param parent [Nokogiri::XML::Node] the parent element
    # @param strix_ns [Nokogiri::XML::Namespace] the strix namespace
    # @param question [Question] the question
    # @param value [Object] the value for the fact
    # @param ctx_id [String] the context ID to reference
    def build_fact_element(doc, parent, strix_ns, question, value, ctx_id)
      fact = Nokogiri::XML::Node.new(question.xbrl_id.to_s, doc)
      fact.namespace = strix_ns
      fact["contextRef"] = ctx_id

      if value.nil?
        # Use xsi:nil="true" for empty facts (all AMSF fields are nillable)
        fact["xsi:nil"] = "true"
      else
        # Add numeric attributes (unitRef, decimals) for numeric types with values
        if numeric_type?(question.type)
          fact["unitRef"] = unit_for(question.type)
          fact["decimals"] = decimals_for(question.type)
        end
        fact.content = format_value(value, question.type)
      end

      parent.add_child(fact)
    end

    # Check if a value is empty (nil or empty hash for dimensional fields).
    # Empty hashes are treated as unanswered for completeness tracking.
    #
    # @param value [Object] the value to check
    # @return [Boolean] true if value is nil or empty hash
    def empty_value?(value)
      value.nil? || (value.is_a?(Hash) && value.empty?)
    end

    # Validate that dimensional fields receive Hash values.
    # Scalar values for dimensional fields would generate incorrect XBRL.
    # Nil values are allowed - Arelle validates completeness.
    #
    # @param question [Question] the dimensional question
    # @param value [Object] the value to validate
    # @raise [GeneratorError] if value is a non-Hash, non-nil type
    def validate_dimensional_value!(question, value)
      return if value.nil? || value.is_a?(Hash)

      raise GeneratorError, "Dimensional field '#{question.xbrl_id}' requires Hash value " \
                            "(e.g., {\"FR\" => 40.0}), got #{value.class}: #{value.inspect}"
    end

    # Check if type is numeric (requires unitRef)
    def numeric_type?(type)
      %i[integer decimal monetary percentage].include?(type)
    end

    # Determine the appropriate unit for a field type
    #
    # @param type [Symbol] the field type
    # @return [String] the unit ID (MONETARY_UNIT_ID for monetary, PURE_UNIT_ID otherwise)
    def unit_for(type)
      type == :monetary ? MONETARY_UNIT_ID : PURE_UNIT_ID
    end

    # Determine decimals attribute based on field type
    #
    # @param type [Symbol] the field type
    # @return [String, nil] the decimals value or nil for non-numeric types
    def decimals_for(type)
      case type
      when :integer
        "0"
      when :decimal, :monetary, :percentage
        "2"
      else
        nil # No decimals for boolean, string, enum, date
      end
    end

    # Format a value for XBRL output
    #
    # @param value [Object] the Ruby value
    # @param type [Symbol] the field type
    # @return [String] the formatted XBRL value
    def format_value(value, type)
      return "" if value.nil?

      case type
      when :decimal, :monetary, :percentage
        format_decimal(value)
      when :date
        format_date_value(value)
      else
        # Booleans, strings, enums, integers - all convert to string
        # Booleans are already stored as "Oui"/"Non" strings by TypeCaster
        value.to_s
      end
    end

    # Format decimal values with 2 decimal places.
    # Uses BigDecimal for precision to avoid floating-point rounding errors,
    # then formats with explicit decimal places to preserve trailing zeros.
    #
    # @param value [Numeric, BigDecimal] the numeric value
    # @return [String] formatted with exactly 2 decimal places (e.g., "5000.50")
    def format_decimal(value)
      rounded = BigDecimal(value.to_s).round(2)
      format("%.2f", rounded)
    end

    # Format date for XBRL period instant
    #
    # @param date [Date] the date
    # @return [String] YYYY-MM-DD format
    def format_date(date)
      date.strftime("%Y-%m-%d")
    end

    # Format date value for XBRL date fields
    # Handles both Date objects and string values
    #
    # @param value [Date, String] the date value
    # @return [String] YYYY-MM-DD format
    def format_date_value(value)
      return value if value.is_a?(String)

      value.strftime("%Y-%m-%d")
    end

    # Format the output based on pretty option
    def format_output(doc)
      if @pretty
        doc.to_xml(indent: 2, save_with: Nokogiri::XML::Node::SaveOptions::FORMAT)
      else
        doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end
    end
  end
end
