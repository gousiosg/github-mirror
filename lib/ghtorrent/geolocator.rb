require 'open-uri'
require 'json'
require 'uri'

module GHTorrent
  module Geolocator
    module OSM

      def format_url(location)
        URI.escape("http://nominatim.openstreetmap.org/search/#{location}?format=json&addressdetails=1&accept_language=en")
      end

      def parse_geolocation_result(location, geocoded)
        if geocoded.empty?
          debug "Geolocation request #{location} returned successfully but no location was found"
          geo       = EMPTY_LOCATION
          geo[:key] = location
          return geo
        else
          debug "Geolocation request for #{location} returned #{geocoded.size} places"
        end

        geocoded = geocoded.sort { |x, y| y['importance'] <=> x['importance'] }.first

        geo = {
            :key          => location,
            :long         => geocoded['lon'],
            :lat          => geocoded['lat'],
            :city         => geocoded['address']['city'],
            :country      => geocoded['address']['country'],
            :state        => geocoded['address']['state'],
            :country_code => geocoded['address']['country_code'],
            :status       => :ok
        }
        geo

      end
    end
  end
end

module GHTorrent
  module Geolocator
    module Bing

      COUNTRY_CODES = File.open(File.join(File.dirname(__FILE__), 'country_codes.txt'), "r:UTF-8").\
        readlines.\
        inject({}) do |acc, x|
          name, code = x.split(/','/)
          acc.merge(name.tr("'", '') => code.strip.tr("'", ''))
        end

    CONFIDENCE_ORDER = {'High' => 3, 'Medium' => 2, 'Low' => 1}

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

        details = geocoded['resourceSets'][0]['resources'].map do |x|
          x['confidence'] = CONFIDENCE_ORDER[x['confidence']]
          x
        end.sort_by do |x|
          x['confidence']
        end.select do |x|
          x['confidence'] == 3
        end.first

        geo = {
            :key          => location,
            :long         => details['point']['coordinates'][1],
            :lat          => details['point']['coordinates'][0],
            :city         => details['address']['locality'],
            :country      => details['address']['countryRegion'],
            :state        => details['address']['adminDistrict'],
            :country_code => COUNTRY_CODES[details['address']['countryRegion']],
            :status       => :ok
        }
        geo
      end
    end
  end
end

module GHTorrent
  module Geolocator
    module GMaps

      def format_url(location)
        URI.escape("https://maps.googleapis.com/maps/api/geocode/json?key=#{config(:geolocation_gmaps_key)}&address=#{location}")
      end

      def parse_geolocation_result(location, geocoded)
        details = geocoded['results'].first
        city_hash = details['address_components'].find{|x| x['types'].include? 'locality'}
        country_hash = details['address_components'].find{|x| x['types'].include? 'country'}
        admin_area_hash = details['address_components'].select{|x| not x['types'].grep(/administrative_area/).empty?}.first

        geo = {
            :key          => location,
            :long         => details['geometry']['location']['lng'],
            :lat          => details['geometry']['location']['lat'],
            :city         => unless city_hash.nil? then city_hash['long_name'] end,
            :country      => unless country_hash.nil? then country_hash['long_name'] end,
            :state        => unless admin_area_hash.nil? then admin_area_hash['long_name'] end,
            :country_code => unless country_hash.nil? then country_hash['short_name'].downcase end,
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
    #   :key          => "larisa",
    #   :long         => 22.41629981994629,
    #   :lat          => 39.61040115356445,
    #   :city         => "Larisa",
    #   :country      => "Greece",
    #   :state        => "Thessaly",
    #   :country_code => "gr",
    #   :status       => :ok
    # }
    # Uses aggressive caching
    def geolocate(location: nil, wait: config(:geolocation_wait).to_i, from_cache: true)
      return EMPTY_LOCATION if location.nil? or location == ''
      location = location_filter(location)

      geo = []
      if from_cache
        geo = persister.find(:geo_cache, {'key' => location})
      end

      if geo.empty?

        if config(:geolocation_service) == 'gmaps'
          self.class.send :include, GHTorrent::Geolocator::GMaps
        elsif config(:geolocation_service) == 'bing'
          self.class.send :include, GHTorrent::Geolocator::Bing
        else
          self.class.send :include, GHTorrent::Geolocator::OSM
        end

        begin
          ts  = Time.now
          url = format_url(location)
          req = open(url)
          p   = JSON.parse(req.read)
          geo = parse_geolocation_result(location, p)

          info "Successful geolocation request. Location: #{location}"
        rescue StandardError => e
          warn "Failed geolocation request. Location: #{location}"
          geo       = EMPTY_LOCATION
          geo[:key] = location
        ensure
          in_db_geo = persister.find(:geo_cache, {'key' => location}).first

          if in_db_geo.nil?
            begin

              geo[:updated_at] = Time.now

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
