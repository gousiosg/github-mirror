require 'mapquest'

module GHTorrent
  def user_geocode(str)
    if ENV['mapquest_key'] then
      mapquest = MapQuest.new API_KEY
      # Instantiate the API using an API key
      mapquest = MapQuest.new(ENV['mapquest_key'],1, true)
      # Get geolocation data
      return mapquest.geocoding.address(str)
    else
      return ""
    end
  end
end
