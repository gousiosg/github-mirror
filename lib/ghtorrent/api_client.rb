require 'open-uri'
require 'net/http'
require 'digest/sha1'
require 'fileutils'
require 'json'

require 'ghtorrent/logging'
require 'ghtorrent/settings'
require 'ghtorrent/time'
require 'version'

module GHTorrent
  module APIClient
    include GHTorrent::Logging
    include GHTorrent::Settings
    include GHTorrent::Logging

    # This is to fix an annoying bug in JRuby's SSL not being able to
    # verify a valid certificate.
    if defined? JRUBY_VERSION
      OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
    end

    # A paged request. Used when the result can expand to more than one
    # result pages.
    def paged_api_request(url, pages = config(:mirror_history_pages_back),
                          last = nil)

      url = ensure_max_per_page(url)
      data = api_request_raw(url)

      return [] if data.nil?

      unless data.meta['link'].nil?
        links = parse_links(data.meta['link'])
        last = links['last'] if last.nil?

        if pages > 0
          pages = pages - 1
          if pages == 0
            return parse_request_result(data)
          end
        end

        if links['next'].nil?
          parse_request_result(data)
        else
          parse_request_result(data) | paged_api_request(links['next'], pages, last)
        end
      else
        parse_request_result(data)
      end
    end


    # A normal request. Returns a hash or an array of hashes representing the
    # parsed JSON result.
    def api_request(url)
      parse_request_result api_request_raw(ensure_max_per_page(url))
    end

    # Determine the number of pages contained in a multi-page API response
    def num_pages(url)
      url = ensure_max_per_page(url)
      data = api_request_raw(url)

      if data.nil? or data.meta.nil? or data.meta['link'].nil?
        return 1
      end

      links = parse_links(data.meta['link'])

      if links.nil? or links['last'].nil?
        return 1
      end

      params = CGI::parse(URI::parse(links['last']).query)
      params['page'][0].to_i
    end

    private

    def ensure_max_per_page(url)
      if url.include?('page')
        if not url.include?('per_page')
          if url.include?('?')
            url + '&per_page=100'
          else
            url + '?per_page=100'
          end
        else
          url
        end
      else
        url
      end
    end

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

      begin
        start_time = Time.now

        contents = do_request(url)
        total = Time.now.to_ms - start_time.to_ms
        debug "[#{@attach_ip}]: Request: #{url} (#{@remaining} remaining), Total: #{total} ms"

        contents
      rescue OpenURI::HTTPError => e
        case e.io.status[0].to_i
          # The following indicate valid Github return codes
          when 400, # Bad request
              401, # Unauthorized
              403, # Forbidden
              404, # Not found
              422 then # Unprocessable entity
            total = Time.now.to_ms - start_time.to_ms
            warn "[#{@attach_ip}]: Request: #{url} (#{@remaining} remaining), Total: #{total} ms, Status: #{e.io.status[1]}"
            @remaining = e.io.meta['x-ratelimit-remaining'].to_i
            @reset = e.io.meta['x-ratelimit-reset'].to_i
            return nil
          else # Server error or HTTP conditions that Github does not report
            warn ": #{url}: #{e.io.status[1]}"
            raise e
        end
      ensure
        # The exact limit is only enforced upon the first @reset
        if 5000 - @remaining > @req_limit
          to_sleep = @reset - Time.now.to_i + 2
          debug "[#{@attach_ip}]: Request limit reached, sleeping for #{to_sleep} secs"
          t = Thread.new do
            slept = 0
            while true do
              debug "[#{@attach_ip}]: sleeping for #{to_sleep - slept} seconds"
              sleep 1
              slept += 1
            end
          end
          sleep(to_sleep)
          t.exit
        end
      end
    end

    def auth_method(username, token)
      if token.nil? or token.empty?
        if username.nil? or username.empty?
          :none
        else
          :username
        end
      else
        :token
      end
    end

    def do_request(url)
      @attach_ip  ||= config(:attach_ip)
      @token      ||= config(:github_token)
      @username   ||= config(:github_username)
      @passwd     ||= config(:github_passwd)
      @user_agent ||= config(:user_agent)
      @remaining  ||= 5000
      @reset      ||= Time.now.to_i + 3600
      @auth_type  ||= auth_method(@username, @token)
      @req_limit  ||= config(:req_limit)

      open_func ||=
          case @auth_type
            when :none
              lambda {|url| open(url, 'User-Agent' => @user_agent)}
            when :username
              lambda {|url| open(url, 'User-Agent' => @user_agent,
                                 :http_basic_authentication => [@username, @passwd])}
            when :token
              # As per: https://developer.github.com/v3/auth/#via-oauth-tokens
              lambda {|url| open(url, 'User-Agent' => @user_agent,
                                 :http_basic_authentication => [@token, 'x-oauth-basic'])}
          end

      result = if @attach_ip.nil? or @attach_ip.eql? '0.0.0.0'
          open_func.call(url)
        else
          attach_to(@attach_ip) do
            open_func.call(url)
          end
        end
      @remaining = result.meta['x-ratelimit-remaining'].to_i
      @reset = result.meta['x-ratelimit-reset'].to_i
      result
    end

    # Attach to a specific IP address if the machine has multiple
    def attach_to(ip)
      TCPSocket.instance_eval do
        (class << self; self; end).instance_eval do
          alias_method :original_open, :open

          case RUBY_VERSION
          when /1.9/
            define_method(:open) do |conn_address, conn_port|
              original_open(conn_address, conn_port, ip)
            end
          when /2.0/
            define_method(:open) do |conn_address, conn_port, local_host, local_port|
              original_open(conn_address, conn_port, ip, local_port)
            end
          end
        end
      end

      result = begin
        yield
      rescue Exception => e
        raise e
      ensure
        TCPSocket.instance_eval do
          (class << self; self; end).instance_eval do
            alias_method :open, :original_open
            remove_method :original_open
          end
        end
      end

      result
    end

  end
end
