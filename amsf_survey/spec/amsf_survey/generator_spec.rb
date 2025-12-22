# frozen_string_literal: true

RSpec.describe AmsfSurvey::Generator do
  # Test fixtures using the test_industry taxonomy
  let(:fixtures_path) { File.expand_path("../fixtures/taxonomies/test_industry/2025", __dir__) }

  # Build a questionnaire with taxonomy_namespace for testing
  let(:questionnaire) do
    AmsfSurvey::Taxonomy::Loader.new(fixtures_path).load(:test_industry, 2025)
  end

  # Helper to create a submission with test data
  def build_submission(data = {})
    # Create submission using the real registry/questionnaire
    submission = AmsfSurvey::Submission.new(
      industry: :test_industry,
      year: 2025,
      entity_id: "ENTITY_001",
      period: Date.new(2025, 12, 31)
    )

    # Stub questionnaire access to use our test fixture
    allow(submission).to receive(:questionnaire).and_return(questionnaire)

    # Set field values
    data.each { |k, v| submission[k] = v }

    submission
  end

  describe "#initialize" do
    it "accepts a submission and optional options" do
      submission = build_submission(tGATE: "Oui")
      generator = described_class.new(submission)

      expect(generator).to be_a(described_class)
    end

    it "accepts options hash" do
      submission = build_submission(tGATE: "Oui")
      generator = described_class.new(submission, pretty: true, include_empty: false)

      expect(generator).to be_a(described_class)
    end
  end

  describe "#generate" do
    # -------------------------------------------------------------------------
    # T008: generates well-formed XML with declaration and encoding
    # -------------------------------------------------------------------------
    context "XML structure" do
      it "generates well-formed XML with declaration and encoding" do
        submission = build_submission(tGATE: "Oui", t001: 100)
        xml = described_class.new(submission).generate

        expect(xml).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
        expect { Nokogiri::XML(xml) { |config| config.strict } }.not_to raise_error
      end

      # -----------------------------------------------------------------------
      # T009: includes required XBRL namespaces
      # -----------------------------------------------------------------------
      it "includes required XBRL namespaces (xbrli, link, xlink, strix)" do
        submission = build_submission(tGATE: "Oui")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        # Check root element is xbrli:xbrl
        expect(doc.root.name).to eq("xbrl")
        expect(doc.root.namespace.prefix).to eq("xbrli")

        # Check namespace declarations
        namespaces = doc.root.namespaces
        expect(namespaces["xmlns:xbrli"]).to eq("http://www.xbrl.org/2003/instance")
        expect(namespaces["xmlns:link"]).to eq("http://www.xbrl.org/2003/linkbase")
        expect(namespaces["xmlns:xlink"]).to eq("http://www.w3.org/1999/xlink")
        expect(namespaces["xmlns:strix"]).to eq(questionnaire.taxonomy_namespace)
      end
    end

    # -------------------------------------------------------------------------
    # T010: generates context with entity identifier and period instant
    # -------------------------------------------------------------------------
    context "XBRL context" do
      it "generates context with entity identifier and period instant" do
        submission = build_submission(tGATE: "Oui")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = {
          "xbrli" => "http://www.xbrl.org/2003/instance"
        }

        # Check context exists with ID
        context = doc.at_xpath("//xbrli:context", ns)
        expect(context).not_to be_nil
        expect(context["id"]).to match(/ctx_/)

        # Check entity identifier
        identifier = doc.at_xpath("//xbrli:context/xbrli:entity/xbrli:identifier", ns)
        expect(identifier).not_to be_nil
        expect(identifier["scheme"]).to eq("https://amlcft.amsf.mc")
        expect(identifier.text).to eq("ENTITY_001")

        # Check period instant
        instant = doc.at_xpath("//xbrli:context/xbrli:period/xbrli:instant", ns)
        expect(instant).not_to be_nil
        expect(instant.text).to eq("2025-12-31")
      end
    end

    # -------------------------------------------------------------------------
    # T011: generates facts with XBRL code element names and contextRef
    # -------------------------------------------------------------------------
    context "XBRL facts" do
      it "generates facts with XBRL code element names and contextRef" do
        submission = build_submission(tGATE: "Oui", t001: 100)
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }

        # The tGATE field should be present
        gate_fact = doc.at_xpath("//strix:tGATE", ns)
        expect(gate_fact).not_to be_nil
        expect(gate_fact["contextRef"]).to match(/ctx_/)

        # The t001 field should be present (depends on tGATE=Oui)
        t001_fact = doc.at_xpath("//strix:t001", ns)
        expect(t001_fact).not_to be_nil
        expect(t001_fact["contextRef"]).to match(/ctx_/)
      end
    end

    # -------------------------------------------------------------------------
    # T012: integer fields have decimals="0" attribute
    # -------------------------------------------------------------------------
    context "decimal precision" do
      it "integer fields have decimals=\"0\" attribute" do
        submission = build_submission(tGATE: "Oui", t001: 150)
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        t001_fact = doc.at_xpath("//strix:t001", ns)

        expect(t001_fact["decimals"]).to eq("0")
        expect(t001_fact.text).to eq("150")
      end

      # -----------------------------------------------------------------------
      # T013: monetary fields have decimals="2" attribute
      # -----------------------------------------------------------------------
      it "monetary fields have decimals=\"2\" attribute" do
        submission = build_submission(tGATE: "Oui", t003: 1234.56)
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        t003_fact = doc.at_xpath("//strix:t003", ns)

        expect(t003_fact["decimals"]).to eq("2")
        expect(t003_fact.text).to eq("1234.56")
      end
    end

    # -------------------------------------------------------------------------
    # T014: boolean fields output value as-is (stored as "Oui"/"Non")
    # Note: TypeCaster preserves boolean string values from taxonomy
    # -------------------------------------------------------------------------
    context "boolean formatting" do
      it "boolean 'Oui' outputs \"Oui\"" do
        submission = build_submission(tGATE: "Oui")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        gate_fact = doc.at_xpath("//strix:tGATE", ns)

        expect(gate_fact.text).to eq("Oui")
        expect(gate_fact["decimals"]).to be_nil # booleans don't have decimals
      end

      it "boolean 'Non' outputs \"Non\"" do
        submission = build_submission(tGATE: "Non")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        gate_fact = doc.at_xpath("//strix:tGATE", ns)

        expect(gate_fact.text).to eq("Non")
      end
    end

    # -------------------------------------------------------------------------
    # T015: enum fields output selected value as content
    # -------------------------------------------------------------------------
    context "enum formatting" do
      it "enum fields output selected value as content" do
        submission = build_submission(tGATE: "Oui", t004: "Option B")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        t004_fact = doc.at_xpath("//strix:t004", ns)

        expect(t004_fact.text).to eq("Option B")
        expect(t004_fact["decimals"]).to be_nil # enums don't have decimals
      end
    end

    # -------------------------------------------------------------------------
    # T016: string fields output text content without decimals
    # -------------------------------------------------------------------------
    context "string formatting" do
      it "string fields output text content without decimals" do
        submission = build_submission(tGATE: "Oui", t002: "Sample comment text")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        t002_fact = doc.at_xpath("//strix:t002", ns)

        expect(t002_fact.text).to eq("Sample comment text")
        expect(t002_fact["decimals"]).to be_nil # strings don't have decimals
      end
    end

    # -------------------------------------------------------------------------
    # T017: escapes special XML characters in values
    # -------------------------------------------------------------------------
    context "XML escaping" do
      it "escapes special XML characters in values" do
        submission = build_submission(tGATE: "Oui", t002: "Test <script>alert('XSS')</script> & entities")
        xml = described_class.new(submission).generate

        # Verify the raw XML contains escaped characters
        expect(xml).to include("&lt;script&gt;")
        expect(xml).to include("&amp;")

        # And verify it parses correctly
        doc = Nokogiri::XML(xml)
        ns = { "strix" => questionnaire.taxonomy_namespace }
        t002_fact = doc.at_xpath("//strix:t002", ns)

        # When parsed, we get the original content back
        expect(t002_fact.text).to eq("Test <script>alert('XSS')</script> & entities")
      end
    end

    # =========================================================================
    # User Story 2: Pretty Printing (T030-T034)
    # =========================================================================
    context "pretty printing option" do
      # T030: default (pretty:false) outputs minified XML
      it "outputs minified XML by default (pretty:false)" do
        submission = build_submission(tGATE: "Oui")
        xml = described_class.new(submission).generate

        # Minified XML should not have leading whitespace on lines
        lines = xml.split("\n")
        # After XML declaration, subsequent lines shouldn't start with whitespace
        content_lines = lines[1..]
        content_lines.each do |line|
          # Minified XML shouldn't have indentation
          expect(line).not_to match(/\A\s+</) unless line.strip.empty?
        end
      end

      # T031: pretty:true outputs indented XML
      it "outputs indented XML when pretty:true" do
        submission = build_submission(tGATE: "Oui")
        xml = described_class.new(submission, pretty: true).generate

        # Pretty XML should have indented child elements
        expect(xml).to include("\n  <") # Indented elements
        expect(xml).to match(/<xbrli:context.*\n\s+<xbrli:entity/m) # Nested indentation
      end
    end

    # =========================================================================
    # User Story 3: Empty Field Handling (T035-T039)
    # =========================================================================
    context "empty field handling option" do
      # T035: include_empty:true (default) includes empty facts for nil values
      it "includes empty facts for nil values by default" do
        submission = build_submission(tGATE: "Oui")
        # t001 is visible (depends on tGATE=Oui) but not set
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        t001_fact = doc.at_xpath("//strix:t001", ns)

        # By default, nil fields should be included as empty elements
        expect(t001_fact).not_to be_nil
        expect(t001_fact.text).to eq("")
      end

      # T036: include_empty:false omits facts for nil values
      it "omits facts for nil values when include_empty:false" do
        submission = build_submission(tGATE: "Oui")
        # t001 is visible but not set (nil)
        xml = described_class.new(submission, include_empty: false).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        t001_fact = doc.at_xpath("//strix:t001", ns)

        # With include_empty:false, nil fields should be omitted
        expect(t001_fact).to be_nil
      end
    end

    # =========================================================================
    # User Story 4: Incomplete Submissions (T040-T044)
    # =========================================================================
    context "incomplete submissions" do
      # T040: generates XML when some fields are missing
      it "generates XML when some fields are missing" do
        submission = build_submission(tGATE: "Oui")
        # Only tGATE is set; other visible fields (t001, t003) are nil

        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        # Should still produce valid XML
        expect(doc.errors).to be_empty
        expect(doc.root.name).to eq("xbrl")
      end

      # T041: hidden fields (gate-controlled) are excluded from output
      it "excludes hidden fields from output" do
        submission = build_submission(tGATE: "Non") # Sets gate to No
        submission[:t001] = 100 # t001 depends on tGATE=Oui, so should be hidden

        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "strix" => questionnaire.taxonomy_namespace }
        t001_fact = doc.at_xpath("//strix:t001", ns)

        # t001 should not appear because tGATE=Non makes it invisible
        expect(t001_fact).to be_nil
      end

      # T042: generates valid context even with no field data
      it "generates valid context even with no field data" do
        submission = build_submission({}) # No data at all

        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "xbrli" => "http://www.xbrl.org/2003/instance" }

        # Context should still be present and valid
        context = doc.at_xpath("//xbrli:context", ns)
        expect(context).not_to be_nil
        expect(context["id"]).to eq("ctx_ENTITY_001_2025")

        identifier = doc.at_xpath("//xbrli:context/xbrli:entity/xbrli:identifier", ns)
        expect(identifier.text).to eq("ENTITY_001")
      end
    end

    # =========================================================================
    # Edge Cases (T045-T047)
    # =========================================================================
    context "edge cases" do
      # T045: period date formatting (YYYY-MM-DD)
      it "formats period date as YYYY-MM-DD" do
        submission = build_submission(tGATE: "Oui")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "xbrli" => "http://www.xbrl.org/2003/instance" }
        instant = doc.at_xpath("//xbrli:context/xbrli:period/xbrli:instant", ns)

        expect(instant.text).to match(/\A\d{4}-\d{2}-\d{2}\z/)
        expect(instant.text).to eq("2025-12-31")
      end

      # T046: entity_id with special characters escaped
      it "escapes special characters in entity_id" do
        submission = AmsfSurvey::Submission.new(
          industry: :test_industry,
          year: 2025,
          entity_id: "ENT<>ID&\"'",
          period: Date.new(2025, 12, 31)
        )
        allow(submission).to receive(:questionnaire).and_return(questionnaire)

        xml = described_class.new(submission).generate

        # Verify the raw XML contains escaped characters
        expect(xml).to include("ENT&lt;&gt;ID&amp;")

        # And verify it parses correctly
        doc = Nokogiri::XML(xml)
        ns = { "xbrli" => "http://www.xbrl.org/2003/instance" }
        identifier = doc.at_xpath("//xbrli:identifier", ns)
        expect(identifier.text).to eq("ENT<>ID&\"'")
      end

      # T047: schemaRef includes correct xlink:href
      it "includes schemaRef with correct filename from taxonomy namespace" do
        submission = build_submission(tGATE: "Oui")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "link" => "http://www.xbrl.org/2003/linkbase" }
        schema_ref = doc.at_xpath("//link:schemaRef", ns)

        expect(schema_ref).not_to be_nil
        expect(schema_ref["xlink:type"]).to eq("simple")
        expect(schema_ref["xlink:href"]).to eq("test_industry_2025.xsd")
      end

      it "handles namespace with query parameters" do
        custom_questionnaire = AmsfSurvey::Questionnaire.new(
          industry: :test_industry,
          year: 2025,
          sections: [],
          taxonomy_namespace: "https://example.com/schema?version=2025"
        )
        submission = build_submission(tGATE: "Oui")
        allow(submission).to receive(:questionnaire).and_return(custom_questionnaire)

        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)
        ns = { "link" => "http://www.xbrl.org/2003/linkbase" }
        schema_ref = doc.at_xpath("//link:schemaRef", ns)

        expect(schema_ref["xlink:href"]).to eq("schema.xsd")
      end

      it "handles namespace with trailing slash" do
        custom_questionnaire = AmsfSurvey::Questionnaire.new(
          industry: :test_industry,
          year: 2025,
          sections: [],
          taxonomy_namespace: "https://example.com/schema/"
        )
        submission = build_submission(tGATE: "Oui")
        allow(submission).to receive(:questionnaire).and_return(custom_questionnaire)

        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)
        ns = { "link" => "http://www.xbrl.org/2003/linkbase" }
        schema_ref = doc.at_xpath("//link:schemaRef", ns)

        # File.basename("/schema/") correctly returns "schema"
        expect(schema_ref["xlink:href"]).to eq("schema.xsd")
      end

      it "falls back to taxonomy.xsd for root-only path" do
        custom_questionnaire = AmsfSurvey::Questionnaire.new(
          industry: :test_industry,
          year: 2025,
          sections: [],
          taxonomy_namespace: "https://example.com/"
        )
        submission = build_submission(tGATE: "Oui")
        allow(submission).to receive(:questionnaire).and_return(custom_questionnaire)

        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)
        ns = { "link" => "http://www.xbrl.org/2003/linkbase" }
        schema_ref = doc.at_xpath("//link:schemaRef", ns)

        expect(schema_ref["xlink:href"]).to eq("taxonomy.xsd")
      end

      # T048: context ID includes entity_id for uniqueness
      it "generates context ID with entity_id for uniqueness" do
        submission = build_submission(tGATE: "Oui")
        xml = described_class.new(submission).generate
        doc = Nokogiri::XML(xml)

        ns = { "xbrli" => "http://www.xbrl.org/2003/instance" }
        context = doc.at_xpath("//xbrli:context", ns)

        expect(context["id"]).to eq("ctx_ENTITY_001_2025")
      end
    end

    # =========================================================================
    # Error Handling (PR Review Feedback)
    # =========================================================================
    context "error handling" do
      it "raises GeneratorError for invalid period type" do
        submission = AmsfSurvey::Submission.new(
          industry: :test_industry,
          year: 2025,
          entity_id: "ENTITY_001",
          period: "2025-12-31" # String instead of Date
        )
        allow(submission).to receive(:questionnaire).and_return(questionnaire)

        expect { described_class.new(submission).generate }
          .to raise_error(AmsfSurvey::GeneratorError, /period must be a Date object/)
      end

      it "raises GeneratorError when questionnaire is nil" do
        submission = AmsfSurvey::Submission.new(
          industry: :test_industry,
          year: 2025,
          entity_id: "ENTITY_001",
          period: Date.new(2025, 12, 31)
        )
        allow(submission).to receive(:questionnaire).and_return(nil)

        expect { described_class.new(submission).generate }
          .to raise_error(AmsfSurvey::GeneratorError, /questionnaire is not available/)
      end
    end
  end
end
