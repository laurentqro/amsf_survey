# frozen_string_literal: true

RSpec.describe "AmsfSurvey Registry" do
  before do
    AmsfSurvey.reset_registry!
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

  describe ".questionnaire" do
    let(:fixtures_path) { File.expand_path("../fixtures/taxonomies", __dir__) }
    let(:taxonomy_path) { File.join(fixtures_path, "test_industry") }

    before do
      AmsfSurvey.register_plugin(industry: :test_industry, taxonomy_path: taxonomy_path)
    end

    it "returns a Questionnaire object" do
      questionnaire = AmsfSurvey.questionnaire(industry: :test_industry, year: 2025)
      expect(questionnaire).to be_a(AmsfSurvey::Questionnaire)
    end

    it "caches the questionnaire on subsequent calls" do
      q1 = AmsfSurvey.questionnaire(industry: :test_industry, year: 2025)
      q2 = AmsfSurvey.questionnaire(industry: :test_industry, year: 2025)
      expect(q1.object_id).to eq(q2.object_id)
    end

    it "returns different questionnaires for different industries" do
      other_path = File.join(fixtures_path, "other_industry", "2025")
      FileUtils.mkdir_p(other_path)
      FileUtils.cp_r(Dir.glob(File.join(taxonomy_path, "2025", "*")), other_path)
      AmsfSurvey.register_plugin(industry: :other_industry, taxonomy_path: File.join(fixtures_path, "other_industry"))

      q1 = AmsfSurvey.questionnaire(industry: :test_industry, year: 2025)
      q2 = AmsfSurvey.questionnaire(industry: :other_industry, year: 2025)
      expect(q1.object_id).not_to eq(q2.object_id)
    ensure
      FileUtils.rm_rf(File.join(fixtures_path, "other_industry"))
    end

    it "raises error for unregistered industry with available options" do
      expect {
        AmsfSurvey.questionnaire(industry: :unknown, year: 2025)
      }.to raise_error(AmsfSurvey::TaxonomyLoadError, /not registered.*Available: test_industry/)
    end

    it "raises error for unregistered industry when none registered" do
      AmsfSurvey.reset_registry!
      expect {
        AmsfSurvey.questionnaire(industry: :unknown, year: 2025)
      }.to raise_error(AmsfSurvey::TaxonomyLoadError, /not registered.*No industries registered yet/)
    end

    it "raises error for unsupported year with available options" do
      expect {
        AmsfSurvey.questionnaire(industry: :test_industry, year: 1999)
      }.to raise_error(AmsfSurvey::TaxonomyLoadError, /not supported.*Available: 2025/)
    end

    it "raises error for unsupported year when no years available" do
      # Register an industry with no year subdirectories
      empty_path = File.join(fixtures_path, "empty_industry")
      FileUtils.mkdir_p(empty_path)
      AmsfSurvey.register_plugin(industry: :empty_industry, taxonomy_path: empty_path)

      expect {
        AmsfSurvey.questionnaire(industry: :empty_industry, year: 2025)
      }.to raise_error(AmsfSurvey::TaxonomyLoadError, /not supported.*No years available/)
    ensure
      FileUtils.rm_rf(empty_path)
    end

    it "raises error for negative year" do
      expect {
        AmsfSurvey.questionnaire(industry: :test_industry, year: -2025)
      }.to raise_error(AmsfSurvey::TaxonomyLoadError, /Invalid year.*positive integer/)
    end

    it "raises error for non-integer year" do
      expect {
        AmsfSurvey.questionnaire(industry: :test_industry, year: "2025")
      }.to raise_error(AmsfSurvey::TaxonomyLoadError, /Invalid year.*positive integer/)
    end
  end
end
