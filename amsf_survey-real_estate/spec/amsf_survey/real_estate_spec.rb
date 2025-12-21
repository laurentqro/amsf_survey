# frozen_string_literal: true

RSpec.describe "AmsfSurvey::RealEstate" do
  describe "plugin registration" do
    it "registers the real estate industry" do
      expect(AmsfSurvey.registered?(:real_estate)).to be true
    end

    it "includes real_estate in registered industries" do
      expect(AmsfSurvey.registered_industries).to include(:real_estate)
    end

    it "provides a valid taxonomy path" do
      # The plugin should have registered with a valid path
      expect(AmsfSurvey.supported_years(:real_estate)).not_to be_empty
    end

    it "supports year 2025" do
      expect(AmsfSurvey.supported_years(:real_estate)).to include(2025)
    end
  end
end
