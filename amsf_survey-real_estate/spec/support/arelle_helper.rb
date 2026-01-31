# frozen_string_literal: true

require "net/http"
require "json"

module ArelleHelper
  ARELLE_URL = ENV.fetch("ARELLE_API_URL", "http://localhost:8000")

  def validate_xbrl(xml)
    uri = URI("#{ARELLE_URL}/validate")
    response = Net::HTTP.post(uri, xml, "Content-Type" => "application/xml")
    JSON.parse(response.body)
  end

  def arelle_available?
    uri = URI("#{ARELLE_URL}/docs")
    Net::HTTP.get_response(uri).is_a?(Net::HTTPSuccess)
  rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
    false
  end
end
