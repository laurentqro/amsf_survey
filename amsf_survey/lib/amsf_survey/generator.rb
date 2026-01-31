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

    # Entity identifier scheme for Monaco AMSF (matches regulatory requirements)
    ENTITY_SCHEME = "https://amlcft.amsf.mc"

    # @param submission [Submission] the source submission object
    # @param options [Hash] generation options
    # @option options [Boolean] :pretty (false) output indented XML
    # @option options [Boolean] :include_empty (true) include empty facts for nil values
    def initialize(submission, options = {})
      @submission = submission
      @pretty = options.fetch(:pretty, false)
      @include_empty = options.fetch(:include_empty, true)
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

      # Create root element with namespaces
      root = Nokogiri::XML::Node.new("xbrl", doc)
      root.add_namespace_definition("xbrli", XBRLI_NS)
      root.add_namespace_definition("link", LINK_NS)
      root.add_namespace_definition("xlink", XLINK_NS)
      root.add_namespace_definition("strix", taxonomy_namespace)
      root.namespace = root.namespace_definitions.find { |ns| ns.prefix == "xbrli" }

      doc.root = root

      # Build child elements
      build_schema_ref(doc, root)
      build_context(doc, root)
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

    # Build fact elements for all visible questions
    def build_facts(doc, parent)
      data = submission.data
      strix_ns = parent.namespace_definitions.find { |ns| ns.prefix == "strix" }

      questionnaire.questions.each do |question|
        next unless question.visible?(data)

        # Use xbrl_id for data lookup (internal storage uses XBRL IDs)
        value = data[question.xbrl_id]

        # Skip nil values if include_empty is false
        next if value.nil? && !@include_empty

        build_fact(doc, parent, strix_ns, question, value)
      end
    end

    # Build a single fact element
    def build_fact(doc, parent, strix_ns, question, value)
      fact = Nokogiri::XML::Node.new(question.xbrl_id.to_s, doc)
      fact.namespace = strix_ns
      fact["contextRef"] = context_id

      # Add decimals attribute for numeric types
      decimals = decimals_for(question.type)
      fact["decimals"] = decimals if decimals

      fact.content = format_value(value, question.type)

      parent.add_child(fact)
    end

    # Determine decimals attribute based on field type
    #
    # @param type [Symbol] the field type
    # @return [String, nil] the decimals value or nil for non-numeric types
    def decimals_for(type)
      case type
      when :integer
        "0"
      when :monetary, :percentage
        "2"
      else
        nil # No decimals for boolean, string, enum
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
      when :monetary, :percentage
        format_decimal(value)
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
