# frozen_string_literal: true

RSpec.describe AmsfSurvey::Taxonomy::XuleParser do
  let(:fixtures_path) { File.expand_path("../../fixtures/taxonomies/test_industry/2025", __dir__) }
  let(:xule_path) { File.join(fixtures_path, "test_survey.xule") }

  describe "#parse" do
    subject(:result) { described_class.new(xule_path).parse }

    it "returns a hash with gate_rules and gate_fields keys" do
      expect(result).to be_a(Hash)
      expect(result.keys).to include(:gate_rules, :gate_fields)
    end

    describe "gate_rules" do
      it "extracts dependencies for controlled fields" do
        rules = result[:gate_rules]
        expect(rules[:t001]).to eq({ tGATE: "Yes" })
        expect(rules[:t003]).to eq({ tGATE: "Yes" })
      end

      it "does not include rules for fields without gate dependencies" do
        rules = result[:gate_rules]
        expect(rules[:t002]).to be_nil
        expect(rules[:t004]).to be_nil
      end
    end

    describe "gate_fields" do
      it "identifies fields that control other fields" do
        gates = result[:gate_fields]
        expect(gates).to include(:tGATE)
      end

      it "does not include controlled fields as gates" do
        gates = result[:gate_fields]
        expect(gates).not_to include(:t001, :t003)
      end
    end
  end

  describe "with missing file" do
    it "returns empty result (xule is optional)" do
      parser = described_class.new("/nonexistent/file.xule")
      result = parser.parse
      expect(result[:gate_rules]).to eq({})
      expect(result[:gate_fields]).to eq([])
    end
  end

  describe "debug logging" do
    around do |example|
      original = ENV.fetch("AMSF_DEBUG", nil)
      ENV["AMSF_DEBUG"] = "1"
      example.run
    ensure
      ENV["AMSF_DEBUG"] = original
    end

    it "logs when skipping unrecognized output patterns" do
      xule_content = <<~XULE
        output invalid_no_hyphen
        message { "Invalid" }
      XULE
      temp_path = File.join(fixtures_path, "temp_invalid.xule")
      File.write(temp_path, xule_content)

      expect { described_class.new(temp_path).parse }.to output(
        /Skipped unrecognized output/
      ).to_stderr
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
    end

    it "logs when skipping non-existence rules" do
      xule_content = <<~XULE
        output tGATE-t001
        $a1 + $a2 == $a3
        message { "Some other rule type" }
      XULE
      temp_path = File.join(fixtures_path, "temp_non_existence.xule")
      File.write(temp_path, xule_content)

      expect { described_class.new(temp_path).parse }.to output(
        /Skipped non-existence rule/
      ).to_stderr
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
    end
  end

  describe "skipping non-gate rules" do
    it "skips sum validation rules (ending in -Sum)" do
      xule_content = <<~XULE
        output a1101-a1102-a1103-Sum
        $a1 >= $a2 + $a3
        message { "Sum check" }

        output tGATE-t001
        $a1 == Yes and $a2>0
        message { "Gate check" }
      XULE
      temp_path = File.join(fixtures_path, "temp_sum.xule")
      File.write(temp_path, xule_content)

      result = described_class.new(temp_path).parse
      expect(result[:gate_rules].keys).not_to include(:a1102, :a1103)
      expect(result[:gate_rules][:t001]).to eq({ tGATE: "Yes" })
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
    end

    it "skips dimension rules (multiple hyphens)" do
      xule_content = <<~XULE
        output a120425O-a1210O-Dimension
        message { "Dimension check" }

        output tGATE-t001
        $a1 == Yes and $a2>0
        message { "Gate check" }
      XULE
      temp_path = File.join(fixtures_path, "temp_dimension.xule")
      File.write(temp_path, xule_content)

      result = described_class.new(temp_path).parse
      expect(result[:gate_rules].keys).to eq([:t001])
    ensure
      File.delete(temp_path) if File.exist?(temp_path)
    end
  end
end
