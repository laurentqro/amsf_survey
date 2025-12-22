# frozen_string_literal: true

RSpec.describe AmsfSurvey::ValidationError do
  describe "#initialize" do
    it "creates an error with required attributes" do
      error = described_class.new(
        field: :total_clients,
        rule: :presence,
        message: "Field 'Total Clients' is required",
        severity: :error
      )

      expect(error.field).to eq(:total_clients)
      expect(error.rule).to eq(:presence)
      expect(error.message).to eq("Field 'Total Clients' is required")
      expect(error.severity).to eq(:error)
      expect(error.context).to eq({})
    end

    it "accepts optional context hash" do
      error = described_class.new(
        field: :percentage,
        rule: :range,
        message: "Value must be at most 100",
        severity: :error,
        context: { value: 150, min: 0, max: 100 }
      )

      expect(error.context).to eq({ value: 150, min: 0, max: 100 })
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      error = described_class.new(
        field: :total_clients,
        rule: :presence,
        message: "Field is required",
        severity: :error,
        context: { expected: 100 }
      )

      expect(error.to_h).to eq({
        field: :total_clients,
        rule: :presence,
        message: "Field is required",
        severity: :error,
        context: { expected: 100 }
      })
    end
  end

  describe "#to_s" do
    it "returns a formatted string" do
      error = described_class.new(
        field: :total_clients,
        rule: :presence,
        message: "Field 'Total Clients' is required",
        severity: :error
      )

      expect(error.to_s).to eq("[error] total_clients: Field 'Total Clients' is required")
    end

    it "shows warning severity" do
      error = described_class.new(
        field: :percentage,
        rule: :range,
        message: "Value exceeds typical range",
        severity: :warning
      )

      expect(error.to_s).to eq("[warning] percentage: Value exceeds typical range")
    end
  end

  describe "severity predicates" do
    it "#error? returns true for error severity" do
      error = described_class.new(
        field: :f, rule: :r, message: "m", severity: :error
      )
      expect(error.error?).to be true
      expect(error.warning?).to be false
    end

    it "#warning? returns true for warning severity" do
      error = described_class.new(
        field: :f, rule: :r, message: "m", severity: :warning
      )
      expect(error.warning?).to be true
      expect(error.error?).to be false
    end
  end
end
