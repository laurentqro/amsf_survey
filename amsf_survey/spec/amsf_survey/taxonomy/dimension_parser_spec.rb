# frozen_string_literal: true

require "spec_helper"

RSpec.describe AmsfSurvey::Taxonomy::DimensionParser do
  let(:taxonomy_path) { File.expand_path("../../../../amsf_survey-real_estate/taxonomies/2025", __dir__) }
  let(:def_path) { File.join(taxonomy_path, "strix_Real_Estate_AML_CFT_survey_2025_def.xml") }

  describe "#parse" do
    subject(:result) { described_class.new(def_path).parse }

    it "returns a hash with dimensional_fields set" do
      expect(result[:dimensional_fields]).to be_a(Set)
    end

    it "identifies dimensional fields from Abstract_aAC group" do
      # a1204S1 is in the Abstract_aAC dimensional group
      expect(result[:dimensional_fields]).to include(:a1204S1)
    end

    it "extracts dimension metadata" do
      expect(result[:dimension_name]).to eq("CountryDimension")
    end

    it "extracts member prefix from domain members" do
      expect(result[:member_prefix]).to eq("sdl")
    end
  end

  describe "with missing file" do
    subject(:result) { described_class.new("/nonexistent/path.xml").parse }

    it "returns empty dimensional_fields" do
      expect(result[:dimensional_fields]).to eq(Set.new)
    end

    it "returns nil dimension_name" do
      expect(result[:dimension_name]).to be_nil
    end

    it "returns nil member_prefix" do
      expect(result[:member_prefix]).to be_nil
    end
  end
end
