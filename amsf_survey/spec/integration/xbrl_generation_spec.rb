# frozen_string_literal: true

RSpec.describe "XBRL Generation Integration" do
  let(:fixtures_path) { File.expand_path("../fixtures/taxonomies/test_industry/2025", __dir__) }

  let(:questionnaire) do
    AmsfSurvey::Taxonomy::Loader.new(fixtures_path).load(:test_industry, 2025)
  end

  def build_submission(data = {})
    submission = AmsfSurvey::Submission.new(
      industry: :test_industry,
      year: 2025,
      entity_id: "TEST_ENTITY_001",
      period: Date.new(2025, 12, 31)
    )
    allow(submission).to receive(:questionnaire).and_return(questionnaire)
    data.each { |k, v| submission[k] = v }
    submission
  end

  # T049: generate XBRL from complete submission
  describe "end-to-end generation" do
    it "generates XBRL from a complete test taxonomy submission" do
      submission = build_submission(
        tGATE: "Oui",
        t001: 100,
        t002: "Test comment",
        t003: 5000.50,
        t004: "Option A"
      )

      xml = AmsfSurvey.to_xbrl(submission)
      doc = Nokogiri::XML(xml)

      # Verify valid XML structure
      expect(doc.errors).to be_empty
      expect(doc.root.name).to eq("xbrl")

      # Verify all facts present
      ns = { "strix" => questionnaire.taxonomy_namespace }
      expect(doc.at_xpath("//strix:tGATE", ns).text).to eq("Oui")
      expect(doc.at_xpath("//strix:t001", ns).text).to eq("100")
      expect(doc.at_xpath("//strix:t002", ns).text).to eq("Test comment")
      expect(doc.at_xpath("//strix:t003", ns).text).to eq("5000.50")
      expect(doc.at_xpath("//strix:t004", ns).text).to eq("Option A")
    end
  end

  # T050: verify output is parseable by Nokogiri
  describe "XML parseability" do
    it "produces output parseable by Nokogiri strict mode" do
      submission = build_submission(tGATE: "Oui", t001: 50)
      xml = AmsfSurvey.to_xbrl(submission)

      # Should not raise any errors
      expect { Nokogiri::XML(xml) { |config| config.strict } }.not_to raise_error

      doc = Nokogiri::XML(xml) { |config| config.strict }
      expect(doc.errors).to be_empty
    end

    it "produces well-formed XML with valid namespaces" do
      submission = build_submission(tGATE: "Oui")
      xml = AmsfSurvey.to_xbrl(submission)
      doc = Nokogiri::XML(xml)

      # Validate namespace resolution
      xbrli_ns = doc.root.namespace_definitions.find { |ns| ns.prefix == "xbrli" }
      expect(xbrli_ns).not_to be_nil
      expect(xbrli_ns.href).to eq("http://www.xbrl.org/2003/instance")
    end
  end

  # T051: performance test
  describe "performance" do
    it "generates XBRL under 100ms for typical submission" do
      submission = build_submission(
        tGATE: "Oui",
        t001: 150,
        t002: "Performance test comment",
        t003: 12345.67,
        t004: "Option B"
      )

      # Warm up (first run may be slower due to lazy initialization)
      AmsfSurvey.to_xbrl(submission)

      # Measure generation time
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      AmsfSurvey.to_xbrl(submission)
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      elapsed_ms = (end_time - start_time) * 1000
      expect(elapsed_ms).to be < 100, "Expected generation under 100ms, got #{elapsed_ms.round(2)}ms"
    end
  end

  describe "AmsfSurvey.to_xbrl convenience method" do
    it "delegates to Generator" do
      submission = build_submission(tGATE: "Oui")

      # Use the module method
      xml = AmsfSurvey.to_xbrl(submission)

      expect(xml).to include('<?xml version="1.0" encoding="UTF-8"?>')
      expect(xml).to include("<xbrli:xbrl")
    end

    it "passes options to Generator" do
      submission = build_submission(tGATE: "Oui")

      xml_pretty = AmsfSurvey.to_xbrl(submission, pretty: true)
      xml_minified = AmsfSurvey.to_xbrl(submission, pretty: false)

      # Pretty should have newlines with indentation
      expect(xml_pretty).to match(/\n\s+</)
      # Minified should not have indentation
      expect(xml_minified.split("\n")[1]).not_to match(/\A\s+</)
    end
  end

  # Regression test for aC1208 validation error
  # XSD contains double-encoded values like Par l&amp;#39;entit&amp;#233;
  # After XML parsing + CGI.unescape_html, valid_values contains: Par l'entité
  # Apps use human-readable values; generator encodes for XBRL output
  describe "HTML-encoded enum values" do
    it "accepts human-readable values and encodes for XBRL" do
      # App uses decoded value
      human_value = "Par l'entité"
      submission = build_submission(tGATE: "Oui", t005: human_value)

      xml = AmsfSurvey.to_xbrl(submission)

      # Generator encodes for XBRL, then Nokogiri XML-escapes the &
      # Result: Par l&amp;#39;entit&amp;#233; in raw XML
      # When Arelle parses this, it gets: Par l&#39;entit&#233;
      # Which matches what Arelle sees in the XSD
      expect(xml).to include("Par l&amp;#39;entit&amp;#233;")

      # Verify round-trip: parsing XBRL gives the encoded form
      doc = Nokogiri::XML(xml)
      ns = { "strix" => questionnaire.taxonomy_namespace }
      parsed_value = doc.at_xpath("//strix:t005", ns).text
      expect(parsed_value).to eq("Par l&#39;entit&#233;")
    end

    it "includes human-readable values in valid_values" do
      question = questionnaire.questions.find { |q| q.id == :t005 }
      # valid_values contains decoded form for app use
      expect(question.valid_values).to include("Par l'entité")
    end
  end
end
