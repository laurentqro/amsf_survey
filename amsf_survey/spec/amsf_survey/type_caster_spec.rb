# frozen_string_literal: true

require "bigdecimal"

RSpec.describe AmsfSurvey::TypeCaster do
  describe ".cast" do
    context "with integer fields" do
      it "casts string to integer" do
        expect(described_class.cast("123", :integer)).to eq(123)
      end

      it "casts negative string to integer" do
        expect(described_class.cast("-42", :integer)).to eq(-42)
      end

      it "returns integer as-is" do
        expect(described_class.cast(100, :integer)).to eq(100)
      end

      it "returns nil for nil" do
        expect(described_class.cast(nil, :integer)).to be_nil
      end

      it "returns nil for empty string" do
        expect(described_class.cast("", :integer)).to be_nil
      end

      it "returns nil for whitespace-only string" do
        expect(described_class.cast("   ", :integer)).to be_nil
      end

      it "returns nil for non-numeric string" do
        expect(described_class.cast("abc", :integer)).to be_nil
      end
    end

    context "with monetary fields" do
      it "casts string to BigDecimal" do
        result = described_class.cast("1234.56", :monetary)
        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("1234.56"))
      end

      it "casts integer to BigDecimal" do
        result = described_class.cast(100, :monetary)
        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("100"))
      end

      it "casts float to BigDecimal" do
        result = described_class.cast(99.99, :monetary)
        expect(result).to be_a(BigDecimal)
        expect(result).to eq(BigDecimal("99.99"))
      end

      it "returns BigDecimal as-is" do
        original = BigDecimal("500.25")
        expect(described_class.cast(original, :monetary)).to eq(original)
      end

      it "returns nil for nil" do
        expect(described_class.cast(nil, :monetary)).to be_nil
      end

      it "returns nil for empty string" do
        expect(described_class.cast("", :monetary)).to be_nil
      end

      it "returns nil for non-numeric string" do
        expect(described_class.cast("invalid", :monetary)).to be_nil
      end
    end

    context "with boolean fields" do
      it "preserves Oui value" do
        expect(described_class.cast("Oui", :boolean)).to eq("Oui")
      end

      it "preserves Non value" do
        expect(described_class.cast("Non", :boolean)).to eq("Non")
      end

      it "returns nil for nil" do
        expect(described_class.cast(nil, :boolean)).to be_nil
      end

      it "returns any string value (validation handles invalid)" do
        expect(described_class.cast("Maybe", :boolean)).to eq("Maybe")
      end
    end

    context "with enum fields" do
      it "preserves string value" do
        expect(described_class.cast("Option A", :enum)).to eq("Option A")
      end

      it "returns nil for nil" do
        expect(described_class.cast(nil, :enum)).to be_nil
      end

      it "converts non-string to string" do
        expect(described_class.cast(123, :enum)).to eq("123")
      end
    end

    context "with string fields" do
      it "preserves string value" do
        expect(described_class.cast("hello", :string)).to eq("hello")
      end

      it "converts integer to string" do
        expect(described_class.cast(42, :string)).to eq("42")
      end

      it "returns nil for nil" do
        expect(described_class.cast(nil, :string)).to be_nil
      end
    end

    context "with unknown field type" do
      it "returns value unchanged" do
        expect(described_class.cast("test", :unknown)).to eq("test")
      end
    end
  end
end
