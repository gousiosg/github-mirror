require 'net/http'
require 'set'
require 'open-uri'
require 'json'

module GHTorrent
  module APIClient
    include GHTorrent::Logging
    include GHTorrent::Settings

    def initialize(settings)
      @num_api_calls = 0
      @ts = Time.now().tv_sec()
    end

    # A paged request. Used when the result can expand to more than one
    # result pages.
    def paged_api_request(url, pages = -1)

      data = api_request_raw(url)

      return [] if data.nil?

      unless data.meta['link'].nil?
        links = parse_links(data.meta['link'])

        if pages > 0
          pages = pages - 1
          if pages == 0
            return parse_request_result(data)
          end
        end

        if links['next'].nil?
          parse_request_result(data)
        else
          parse_request_result(data) | paged_api_request(links['next'], pages)
        end
      else
        parse_request_result(data)
      end
    end

    # A normal request. Returns a hash or an array of hashes representing the
    # parsed JSON result.
    def api_request(url)
      parse_request_result api_request_raw(url)
    end

    private

    # Parse a Github link header
    def parse_links(links)
      links.split(/,/).reduce({}) do |acc, x|
        matches = x.strip.match(/<(.*)>; rel=\"(.*)\"/)
        acc[matches[2]] = matches[1]
        acc
      end
    end

    # Parse the JSON result array
    def parse_request_result(result)
      if result.nil?
        []
      else
        json = result.read
        if json.nil?
          []
        else
          JSON.parse(json)
        end
      end
    end

    # Do the actual request and return the result object
    def api_request_raw(url)
      #Rate limiting to avoid error requests
      if Time.now().tv_sec() - @ts < 60 then
        if @num_api_calls >= @settings['mirror']['reqrate'].to_i
          sleep = 60 - (Time.now().tv_sec() - @ts)
          debug "APIClient: Sleeping for #{sleep}"
          sleep (sleep)
          @num_api_calls = 0
          @ts = Time.now().tv_sec()
        end
      else
        debug "APIClient: Tick, num_calls = #{@num_api_calls}, zeroing"
        @num_api_calls = 0
        @ts = Time.now().tv_sec()
      end

      @num_api_calls += 1
      begin
        start_time = Time.now
        contents = open(url)
        total = Time.now.to_ms - start_time.to_ms
        debug "APIClient: Request: #{url} (#{@num_api_calls} calls, #{total} ms)"
        contents
      rescue OpenURI::HTTPError => e
        case e.io.status[0].to_i
          # The following indicate valid Github return codes
          when 400, # Bad request
              401, # Unauthorized
              403, # Forbidden
              404, # Not found
              422 : # Unprocessable entity
            STDERR.puts "#{url}: #{e.io.status[1]}"
            return nil
          else # Server error or HTTP conditions that Github does not report
            STDERR.puts "#{url}"
            raise e
        end
      end
    end
  end
end