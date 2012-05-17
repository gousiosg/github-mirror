# Copyright 2012 Georgios Gousios <gousiosg@gmail.com>
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#   1. Redistributions of source code must retain the above
#      copyright notice, this list of conditions and the following
#      disclaimer.
#
#   2. Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials
#      provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

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
      result = api_request_raw(url)
      if result.nil?
        nil
      else
        JSON.parse(result)
      end
    end

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
      debug "APIClient: Request: #{url} (num_calls = #{@num_api_calls})"
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
            STDERR.puts "#{url}: #{e.io.status[1]}"
            return nil
          else # Server error or HTTP conditions that Github does not report
            raise e
        end
      end
    end
  end
end