# frozen_string_literal: true

RSpec.describe AmsfSurvey::ValidationResult do
  let(:presence_error) do
    AmsfSurvey::ValidationError.new(
      field: :total_clients,
      rule: :presence,
      message: "Field is required",
      severity: :error
    )
  end

  let(:range_error) do
    AmsfSurvey::ValidationError.new(
      field: :percentage,
      rule: :range,
      message: "Value exceeds maximum",
      severity: :error,
      context: { value: 150, max: 100 }
    )
  end

  let(:warning) do
    AmsfSurvey::ValidationError.new(
      field: :optional_field,
      rule: :recommendation,
      message: "Consider filling this field",
      severity: :warning
    )
  end

  describe "#initialize" do
    it "creates result with errors and warnings" do
      result = described_class.new(
        errors: [presence_error, range_error],
        warnings: [warning]
      )

      expect(result.errors).to contain_exactly(presence_error, range_error)
      expect(result.warnings).to contain_exactly(warning)
    end

    it "freezes the arrays" do
      result = described_class.new(errors: [presence_error], warnings: [])

      expect(result.errors).to be_frozen
      expect(result.warnings).to be_frozen
    end

    it "defaults to empty arrays" do
      result = described_class.new

      expect(result.errors).to eq([])
      expect(result.warnings).to eq([])
    end
  end

  describe "#valid?" do
    it "returns true when no errors" do
      result = described_class.new(errors: [], warnings: [warning])
      expect(result.valid?).to be true
    end

    it "returns false when errors exist" do
      result = described_class.new(errors: [presence_error], warnings: [])
      expect(result.valid?).to be false
    end
  end

  describe "#complete?" do
    it "returns true when no presence errors" do
      result = described_class.new(errors: [range_error], warnings: [])
      expect(result.complete?).to be true
    end

    it "returns false when presence errors exist" do
      result = described_class.new(errors: [presence_error], warnings: [])
      expect(result.complete?).to be false
    end
  end

  describe "#error_count" do
    it "returns count of errors" do
      result = described_class.new(errors: [presence_error, range_error], warnings: [warning])
      expect(result.error_count).to eq(2)
    end
  end

  describe "#warning_count" do
    it "returns count of warnings" do
      result = described_class.new(errors: [presence_error], warnings: [warning])
      expect(result.warning_count).to eq(1)
    end
  end

  describe "#errors_for" do
    it "returns errors for a specific field" do
      result = described_class.new(errors: [presence_error, range_error], warnings: [])
      expect(result.errors_for(:total_clients)).to contain_exactly(presence_error)
    end

    it "returns empty array when no errors for field" do
      result = described_class.new(errors: [presence_error], warnings: [])
      expect(result.errors_for(:unknown_field)).to eq([])
    end
  end
end
