require 'mapquest'

module GHTorrent
  def user_geocode(str)
    if ENV['mapquest_key'] then
      mapquest = MapQuest.new API_KEY
      # Instantiate the API using an API key
      mapquest = MapQuest.new(ENV['mapquest_key'],1, true)
      # Get geolocation data
      resp = mapquest.geocoding.reverse((mapquest.geocoding.address(str))[0])
      return Array[resp.latLng, resp.adminArea1, resp.adminArea3, resp.adminArea5]
    else
      return ""
    end
  end
end
