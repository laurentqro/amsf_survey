# frozen_string_literal: true

RSpec.describe "AmsfSurvey Registry" do
  before do
    # Reset registry before each test
    AmsfSurvey.instance_variable_set(:@registry, {})
  end

  describe ".register_plugin" do
    let(:taxonomy_path) { File.expand_path("../../fixtures/taxonomies/test_industry", __dir__) }

    before do
      FileUtils.mkdir_p(taxonomy_path)
    end

    after do
      FileUtils.rm_rf(taxonomy_path)
    end

    it "registers an industry plugin" do
      AmsfSurvey.register_plugin(industry: :test_industry, taxonomy_path: taxonomy_path)

      expect(AmsfSurvey.registered?(:test_industry)).to be true
    end

    it "stores the taxonomy path" do
      AmsfSurvey.register_plugin(industry: :test_industry, taxonomy_path: taxonomy_path)

      expect(AmsfSurvey.registered_industries).to include(:test_industry)
    end

    it "raises error for missing taxonomy path" do
      expect {
        AmsfSurvey.register_plugin(industry: :bad, taxonomy_path: "/nonexistent/path")
      }.to raise_error(AmsfSurvey::TaxonomyPathError)
    end

    it "raises error for duplicate registration" do
      AmsfSurvey.register_plugin(industry: :test_industry, taxonomy_path: taxonomy_path)

      expect {
        AmsfSurvey.register_plugin(industry: :test_industry, taxonomy_path: taxonomy_path)
      }.to raise_error(AmsfSurvey::DuplicateIndustryError)
    end
  end

  describe ".registered_industries" do
    it "returns empty array when no plugins registered" do
      expect(AmsfSurvey.registered_industries).to eq([])
    end
  end

  describe ".registered?" do
    it "returns false for unknown industry" do
      expect(AmsfSurvey.registered?(:nonexistent)).to be false
    end
  end

  describe ".supported_years" do
    let(:taxonomy_path) { File.expand_path("../../fixtures/taxonomies/test_industry", __dir__) }
    let(:year_2025_path) { File.join(taxonomy_path, "2025") }

    before do
      FileUtils.mkdir_p(year_2025_path)
      AmsfSurvey.register_plugin(industry: :test_industry, taxonomy_path: taxonomy_path)
    end

    after do
      FileUtils.rm_rf(taxonomy_path)
    end

    it "returns detected years from taxonomy subdirectories" do
      expect(AmsfSurvey.supported_years(:test_industry)).to eq([2025])
    end

    it "returns empty array for unregistered industry" do
      expect(AmsfSurvey.supported_years(:unknown)).to eq([])
    end
  end
end
