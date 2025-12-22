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

      # Regulatory financial data precision edge cases
      context "decimal precision for regulatory data" do
        it "handles very large monetary values" do
          result = described_class.cast("999999999999999.99", :monetary)
          expect(result).to eq(BigDecimal("999999999999999.99"))
          expect(result.to_s("F")).to eq("999999999999999.99")
        end

        it "preserves high precision decimals" do
          result = described_class.cast("1234.123456789", :monetary)
          expect(result).to eq(BigDecimal("1234.123456789"))
          # Verify precision is maintained
          expect(result.to_s("F")).to include("1234.123456789")
        end

        it "handles scientific notation" do
          result = described_class.cast("1.23e5", :monetary)
          expect(result).to eq(BigDecimal("123000"))
        end

        it "handles negative scientific notation" do
          result = described_class.cast("1.5e-3", :monetary)
          expect(result).to eq(BigDecimal("0.0015"))
        end

        it "handles zero with decimals" do
          result = described_class.cast("0.00", :monetary)
          expect(result).to eq(BigDecimal("0"))
          expect(result.zero?).to be true
        end

        it "handles negative monetary values" do
          result = described_class.cast("-12345.67", :monetary)
          expect(result).to eq(BigDecimal("-12345.67"))
          expect(result.negative?).to be true
        end

        it "handles European decimal format with comma" do
          # Note: BigDecimal doesn't parse comma as decimal separator
          # This documents expected behavior - commas are invalid
          result = described_class.cast("1234,56", :monetary)
          expect(result).to be_nil
        end

        it "handles thousands separators (invalid)" do
          # BigDecimal doesn't parse thousands separators
          result = described_class.cast("1,234.56", :monetary)
          expect(result).to be_nil
        end

        it "preserves exact decimal representation vs float" do
          # This is why we use BigDecimal - floats have precision issues
          result = described_class.cast("0.1", :monetary)
          # Float would give 0.1000000000000000055511151231257827021181583404541015625
          expect(result).to eq(BigDecimal("0.1"))
          expect(result + BigDecimal("0.2")).to eq(BigDecimal("0.3"))
        end
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

      it "returns nil for empty string" do
        expect(described_class.cast("", :boolean)).to be_nil
      end

      it "returns nil for whitespace-only string" do
        expect(described_class.cast("   ", :boolean)).to be_nil
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

      it "returns nil for empty string" do
        expect(described_class.cast("", :enum)).to be_nil
      end

      it "returns nil for whitespace-only string" do
        expect(described_class.cast("   ", :enum)).to be_nil
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

      it "returns nil for empty string" do
        expect(described_class.cast("", :string)).to be_nil
      end

      it "returns nil for whitespace-only string" do
        expect(described_class.cast("   ", :string)).to be_nil
      end
    end

    context "with unknown field type" do
      it "returns value unchanged" do
        expect(described_class.cast("test", :unknown)).to eq("test")
      end
    end
  end
end
