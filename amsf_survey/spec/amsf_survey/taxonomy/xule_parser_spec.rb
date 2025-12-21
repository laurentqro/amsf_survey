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
end
