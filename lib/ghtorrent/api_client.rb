require 'open-uri'
require 'net/http'
require 'digest/sha1'
require 'fileutils'
require 'json'

require 'ghtorrent/logging'
require 'ghtorrent/settings'
require 'ghtorrent/time'
require 'ghtorrent/cache'
require 'version'

module GHTorrent
  module APIClient
    include GHTorrent::Logging
    include GHTorrent::Settings
    include GHTorrent::Cache
    include GHTorrent::Logging

    # This is to fix an annoying bug in JRuby's SSL not being able to
    # verify a valid certificate.
    if defined? JRUBY_VERSION
      OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
    end

    # A paged request. Used when the result can expand to more than one
    # result pages.
    def paged_api_request(url, pages = config(:mirror_history_pages_back),
        cache = true, last = nil)

      url = if not url.include?("per_page")
              if url.include?("?")
                url + "&per_page=100"
              else
                url + "?per_page=100"
              end
            else
              url
            end

      data = if CGI::parse(URI::parse(url).query).has_key?("page")
               api_request_raw(url, use_cache?(cache, method = :paged))
             else
               api_request_raw(url, false)
             end

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
          parse_request_result(data) |
              if links['next'] == last
                if last != links['last']
                  warn "APIClient: Last header mismatch: method=#{last}, cache=#{links['last']}"
                end
                paged_api_request(links['next'], pages, false, last)
              else
                paged_api_request(links['next'], pages, cache, last)
              end
        end
      else
        parse_request_result(data)
      end
    end

    # A normal request. Returns a hash or an array of hashes representing the
    # parsed JSON result.
    def api_request(url, cache = false)
      parse_request_result api_request_raw(url, use_cache?(cache))
    end

    private

    # Determine whether to use cache or not, depending on the type of the
    # request
    def use_cache?(client_request, method = :non_paged)
      @cache_mode ||= case config(:cache_mode)
                        when "dev"
                          :dev
                        when "prod"
                          :prod
                        else
                          raise GHTorrentException.new("Don't know cache configuration #{@cache_mode}")
                      end
      case @cache_mode
        when :dev
          unless client_request
            return false
          end
          return true
        when :prod
          if client_request
            return true
          else
            case method
              when :non_paged
                return false
              when :paged
                return true
            end
          end
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
    def api_request_raw(url, use_cache = false)

      begin
        start_time = Time.now
        from_cache = false

        contents =
            if use_cache
              if not (cached = cache_get(url)).nil?
                from_cache = true
                cached
              else
                tocache = Cachable.new(do_request(url))
                cache_put(url, tocache)
                tocache
              end
            else
              do_request(url)
            end

        total = Time.now.to_ms - start_time.to_ms
        debug "APIClient: Request: #{url} #{if from_cache then " from cache," else "(#{contents.meta['x-ratelimit-remaining']} remaining)," end} Total: #{total} ms"

        if config(:respect_api_ratelimit) and
            contents.meta['x-ratelimit-remaining'].to_i < 20
          sleep = 61 - Time.now.min
          debug "APIClient: Request limit reached, sleeping for #{sleep} min"
          sleep(sleep * 60)
        end

        contents
      rescue OpenURI::HTTPError => e
        case e.io.status[0].to_i
          # The following indicate valid Github return codes
          when 400, # Bad request
              401, # Unauthorized
              403, # Forbidden
              404, # Not found
              422 then # Unprocessable entity
            warn "#{url}: #{e.io.status[1]}"
            return nil
          else # Server error or HTTP conditions that Github does not report
            warn "#{url}"
            raise e
        end
      end
    end

    def do_request(url)
      @attach_ip ||= config(:attach_ip)
      @username ||= config(:github_username)
      @passwd ||= config(:github_passwd)
      #@user_agent ||= "ghtorrent-v#{GHTorrent::VERSION}"
      @user_agent ||= "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.101 Safari/537.11"

      @open_func ||= if @username.nil?
        lambda {|url| open(url, 'User-Agent' => @user_agent)}
      else
        lambda {|url| open(url,
                           'User-Agent' => @user_agent,
                           :http_basic_authentication => [@username, @passwd])}
      end

      if @attach_ip.nil? or @attach_ip.eql? "0.0.0.0"
        @open_func.call(url)
      else
        attach_to(@attach_ip) do
          @open_func.call(url)
        end
      end
    end

    # Attach to a specific IP address if the machine has multiple
    def attach_to(ip)
      TCPSocket.instance_eval do
        (class << self; self; end).instance_eval do
          alias_method :original_open, :open

          define_method(:open) do |conn_address, conn_port|
            original_open(conn_address, conn_port, ip)
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

class Cachable

  include OpenURI::Meta

  attr_reader :base_uri, :meta, :status

  def initialize(response)
    @data = response.read
    @base_uri = response.base_uri
    @meta = response.meta
    @status = response.status
  end

  def read
    @data
  end

end
