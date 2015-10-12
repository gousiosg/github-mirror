require 'open-uri'
require 'json'
require 'uri'

module GHTorrent
  module Geolocator

    EMPTY_LOCATION = {
        :key => nil,
        :long => nil,
        :lat => nil,
        :city => nil,
        :country => nil,
        :state => nil,
        :country_code => nil,
        :status => :failed
    }

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
    def geolocate(location, wait = config(:geoloc_wait))
      return EMPTY_LOCATION if location.nil? or location == ''
      location = location_filter(location)

      geo = persister.find(:geo_cache, {'key' => location})

      if geo.empty?
        begin
          ts = Time.now
          url = URI.escape("http://nominatim.openstreetmap.org/search/#{location}?format=json&addressdetails=1&accept_language=en")
          req = open(url)
          geocoded = JSON.parse(req.read)

          if geocoded.empty?
            debug "Geolocation request #{url} returned successfully but no location was found"
            geo = EMPTY_LOCATION
            geo[:key] = location
            return geo
          else
            debug "Geolocation request #{url} returned #{geocoded.size} places"
          end

          geocoded = geocoded.sort { |x, y| y['importance'] <=> x['importance'] }.first

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
          info "Successful geolocation request. Location: #{location}, URL: #{url}"
        rescue
          warn "Failed geolocation request. URL: #{url}"
          geo = EMPTY_LOCATION
          geo[:key] = location
        ensure
          persister.store(:geo_cache, geo)
          geo = persister.find(:geo_cache, {'key' => location}).first 
          info "Added location key '#{location}' -> #{geo[:status]}"
          taken = Time.now.to_f - ts.to_f
          to_sleep = wait - taken
          sleep(to_sleep) if to_sleep > 0
        end
      else
        geo = geo[0]
        debug "Location with key '#{location}' exists"
      end

      geo
    end

    # Standard filtering on all locations used by GHTorrent
    def location_filter(location)
      return nil if location.nil?
      location.\
        strip.\
        downcase.
        tr('#"<>[]', '').\
        gsub(/^[0-9,\/().:]*/, '').\
        gsub(/ +/, ' ').\
        gsub(/,([a-z]*)/, '\1')
    end
  end
end
