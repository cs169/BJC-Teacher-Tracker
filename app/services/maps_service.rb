# frozen_string_literal: true

module MapsService
  # Get latitude and longitude from address
  def self.get_lat_lng(address)
    return nil if address.blank?

    address = CGI.escape(address)
    url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{address}&key=#{ENV['BACKEND_MAPS_API_KEY']}"
    response = HTTParty.get(url)
    return nil if response["status"] != "OK"

    response["results"][0]["geometry"]["location"].with_indifferent_access
    end
end
