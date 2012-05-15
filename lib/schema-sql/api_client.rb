require 'net/http'
require 'logger'
require 'set'
require 'open-uri'
require 'json'

module GHTorrent
  module APIClient
    include GHTorrent::Logging

    @num_api_calls = 0
    @ts = Time.now().tv_sec()
    
    def paged_api_request(url, pages = -1)

      pg = if pages == -1 then
             1000000
           else
             pages
           end
      result = Array.new

      (1..pg).each { |x|
        data = api_request("#{url}?page=#{x}")
        result += data
        break if data.empty?
      }
      result
    end

    def api_request(url)
      JSON.parse(api_request_raw(url))
    end

    def api_request_raw(url)
      #Rate limiting to avoid error requests
      if Time.now().tv_sec() - @ts < 60 then
        if @num_api_calls >= @settings['mirror']['reqrate'].to_i
          sleep = 60 - (Time.now().tv_sec() - @ts)
          debug "Sleeping for #{sleep}"
          sleep (sleep)
          @num_api_calls = 0
          @ts = Time.now().tv_sec()
        end
      else
        debug "Tick, num_calls = #{@num_api_calls}, zeroing"
        @num_api_calls = 0
        @ts = Time.now().tv_sec()
      end

      @num_api_calls += 1
      debug "Request: #{url} (num_calls = #{num_api_calls})"
      begin
        open(url).read
      rescue OpenURI::HTTPError => e
        case e.io.status[0].to_i
          # The following indicate valid Github return codes
          when 400, # Bad request
              401, # Unauthorized
              403, # Forbidden
              404, # Not found
              422 : # Unprocessable entity
            error = {"error" => e.io.status[1]}
            return error.to_json
          else # Server error or HTTP conditions that Github does not report
            raise e
        end
      end
    end
  end
end