# frozen_string_literal: true

RSpec.describe "Plugin loading integration" do
  it "loads plugin when required in fresh environment" do
    # Run in subprocess to get a clean Ruby environment
    result = `ruby -I#{lib_path} -I#{plugin_lib_path} -e "
      require 'amsf_survey'
      puts AmsfSurvey.registered_industries.inspect
      require 'amsf_survey/real_estate'
      puts AmsfSurvey.registered_industries.inspect
      puts AmsfSurvey.registered?(:real_estate)
    " 2>&1`

    lines = result.strip.split("\n")

    expect(lines[0]).to eq("[]"), "Expected empty registry before plugin load"
    expect(lines[1]).to eq("[:real_estate]"), "Expected :real_estate after plugin load"
    expect(lines[2]).to eq("true"), "Expected registered? to return true"
  end

  it "detects taxonomy years from plugin" do
    result = `ruby -I#{lib_path} -I#{plugin_lib_path} -e "
      require 'amsf_survey/real_estate'
      AmsfSurvey.supported_years(:real_estate).each { |y| puts y }
    " 2>&1`

    years = result.strip.split("\n").map(&:to_i)
    expect(years).to be_an(Array)
    years.each do |year|
      expect(year).to be_between(1900, 2099)
    end
  end

  private

  def lib_path
    File.expand_path("../../lib", __dir__)
  end

  def plugin_lib_path
    File.expand_path("../../../amsf_survey-real_estate/lib", __dir__)
  end
end
