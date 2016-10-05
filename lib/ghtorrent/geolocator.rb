require 'open-uri'
require 'json'
require 'uri'

module GHTorrent
  module Geolocator
    module OSM

      def format_url(location)
        URI.escape("http://nominatim.openstreetmap.org/search/#{location}?format=json&addressdetails=1&accept_language=en")
      end

      def parse_geolocation_result(url, geocoded)
        if geocoded.empty?
          debug "Geolocation request #{url} returned successfully but no location was found"
          geo       = EMPTY_LOCATION
          geo[:key] = location
          return geo
        else
          debug "Geolocation request #{url} returned #{geocoded.size} places"
        end

        geocoded = geocoded.sort { |x, y| y['importance'] <=> x['importance'] }.first

        {
            :key          => location,
            :long         => geocoded['lon'],
            :lat          => geocoded['lat'],
            :city         => geocoded['address']['city'],
            :country      => geocoded['address']['country'],
            :state        => geocoded['address']['state'],
            :country_code => geocoded['address']['country_code'],
            :status       => :ok
        }

      end
    end
  end
end

module GHTorrent
  module Geolocator
    module Bing

      def format_url(location)
        URI.escape("http://dev.virtualearth.net/REST/v1/Locations?q=#{location}&key=#{config(:geolocation_bing_key)}")
      end

      def parse_geolocation_result(location, geocoded)
        if geocoded['resourceSets'].nil? or geocoded['resourceSets'][0].nil? or
            geocoded['resourceSets'][0]['estimatedTotal'] < 1
          debug "Geolocation request for #{location} returned successfully but no location was found"
          geo       = EMPTY_LOCATION
          geo[:key] = location
          return geo
        else
          debug "Geolocation request for #{location} returned #{geocoded['resourceSets'][0]['estimatedTotal']} places"
        end

        details = geocoded['resourceSets'][0]['resources'].select{|x| x['confidence'] == 'High'}.first
        puts details

        geo = {
            :key          => location,
            :long         => details['point']['coordinates'][1],
            :lat          => details['point']['coordinates'][0],
            :city         => details['address']['locality'],
            :country      => details['address']['countryRegion'],
            :state        => details['address']['adminDistrict'],
            :country_code => 'nl', #FIXME: not all cities are in NL
            :status       => :ok
        }
        geo
      end
    end
  end
end

module GHTorrent
  module Geolocator

    include GHTorrent::Settings

    EMPTY_LOCATION = {
        :key          => nil,
        :long         => nil,
        :lat          => nil,
        :city         => nil,
        :country      => nil,
        :state        => nil,
        :country_code => nil,
        :status       => :failed
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
    def geolocate(location, wait = config(:geolocation_wait).to_i)
      return EMPTY_LOCATION if location.nil? or location == ''
      location = location_filter(location)

      geo = persister.find(:geo_cache, {'key' => location})

      if geo.empty?

        if config(:geolocation_service) == 'osm'
          self.class.send :include, GHTorrent::Geolocator::OSM
        else
          self.class.send :include, GHTorrent::Geolocator::Bing
        end

        begin
          ts  = Time.now
          url = format_url(location)
          req = open(url)
          p = JSON.parse(req.read)
          geo = parse_geolocation_result(location, p)

          info "Successful geolocation request. Location: #{location}, URL: #{url}"
        rescue
          warn "Failed geolocation request. URL: #{url}"
          geo       = EMPTY_LOCATION
          geo[:key] = location
        ensure
          in_db_geo = persister.find(:geo_cache, {'key' => location}).first

          if in_db_geo.nil?
            begin
              persister.store(:geo_cache, geo)
            rescue StandardError => e
              warn "Could not save location #{location} -> #{geo}: #{e.message}"
            end
          end

          info "Added location key '#{location}' -> #{geo[:status]}"
          taken    = Time.now.to_f - ts.to_f
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
        downcase.\
        tr('#"<>[]', '').\
        gsub(/^[0-9,\/().:]*/, '').\
        gsub(/ +/, ' ').\
        gsub(/,([a-z]*)/, '\1')
    end
  end
end
