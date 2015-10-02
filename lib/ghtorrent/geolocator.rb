require 'open-uri'
require 'json'
require 'uri'

module GHTorrent
  module Geolocator

    def persister
      raise Exception.new("Unimplemented")
    end

    # Given a location string, it returns a hash like the following:
    #
    # input: Larisa, Greece
    # output:
    # {
    #   :key          => "Larisa, Greece" # The actual key used for searcing
    #   :long         => "22.417088"
    #   :lat          => "39.6369927"
    #   :country_code => "gr",
    #   :country      => "Ελλάδα",  #local language name
    #   :city         => "Λάρισα",  #local language name
    #   :state        => "Αποκεντρωμένη Διοίκηση Θεσσαλίας - Στερεάς Ελλάδας",
    #   :status       => "ok"       #or failed, if geolocation failed
    # }
    #
    # Uses OSM and aggressive caching
    def geolocate(location)

      return {:key => location, :status => :failed} if location.strip.empty?

      location = location_filter(location)

      geo = persister.find(:geo_cache, {'key' => location})

      unless geo.empty?
        begin
          url = URI.escape("http://nominatim.openstreetmap.org/search/#{location}?format=json&addressdetails=1&accept_language=en")
          geocoded = JSON.parse(open(url).read).sort { |x, y| y['importance'] <=> x['importance'] }.first

          geo = {
              :key => location,
              :long => geocoded['lon'],
              :lat => geocoded['lat'],
              :city => geocoded['address']['city'],
              :country => geocoded['address']['country'],
              :state => geocoded['address']['state'],
              :country_code => geocoded['address']['country_code'],
              :status => :ok
          }
          info "Added location #{location}"
        rescue
          warn "Could not find location #{location}"
          geo = {:key => location, :status => :failed}
        ensure
          taken = Time.now.to_f - ts.to_f
          sleep(2 - taken) if 2 - taken > 0
        end
      end

      geo
    end

    # Standard filtering on all locations used by GHTorrent
    def location_filter(location)
      location.\
        strip.\
        downcase.\
        tr('#"<>', '').\
        gsub(/^[0-9,\/().:]*/, '').\
        gsub(/ +/, ' ').\
        gsub(/,([a-z]*)/, '\1')
    end
  end
end