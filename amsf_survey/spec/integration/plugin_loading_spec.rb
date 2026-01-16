# frozen_string_literal: true

RSpec.describe "Plugin loading integration" do
  it "loads plugin when required in fresh environment" do
    # Run in subprocess with clean environment (no Bundler interference)
    result = Bundler.with_unbundled_env do
      `ruby -I#{lib_path} -I#{plugin_lib_path} -e "
        require 'amsf_survey'
        puts AmsfSurvey.registered_industries.inspect
        require 'amsf_survey/real_estate'
        puts AmsfSurvey.registered_industries.inspect
        puts AmsfSurvey.registered?(:real_estate)
      " 2>&1`
    end

    lines = result.strip.split("\n").reject { |l| l.include?("warning:") }

    expect(lines[0]).to eq("[]"), "Expected empty registry before plugin load"
    expect(lines[1]).to eq("[:real_estate]"), "Expected :real_estate after plugin load"
    expect(lines[2]).to eq("true"), "Expected registered? to return true"
  end

  it "detects taxonomy years from plugin" do
    result = Bundler.with_unbundled_env do
      `ruby -I#{lib_path} -I#{plugin_lib_path} -e "
        require 'amsf_survey/real_estate'
        AmsfSurvey.supported_years(:real_estate).each { |y| puts y }
      " 2>&1`
    end

    years = result.strip.split("\n").reject { |l| l.include?("warning:") }.map(&:to_i)
    expect(years).to be_an(Array)
    expect(years).not_to be_empty, "Expected at least one taxonomy year"
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
