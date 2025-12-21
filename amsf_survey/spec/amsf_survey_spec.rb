# frozen_string_literal: true

RSpec.describe AmsfSurvey do
  describe "VERSION" do
    it "has a version number" do
      expect(AmsfSurvey::VERSION).not_to be_nil
    end

    it "follows semantic versioning format" do
      expect(AmsfSurvey::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe ".registered_industries" do
    it "returns an array" do
      expect(described_class.registered_industries).to be_an(Array)
    end
  end

  describe ".registered?" do
    it "returns false for unregistered industry" do
      expect(described_class.registered?(:unknown)).to be false
    end
  end

  describe ".supported_years" do
    it "returns an empty array for unregistered industry" do
      expect(described_class.supported_years(:unknown)).to eq([])
    end
  end
end
