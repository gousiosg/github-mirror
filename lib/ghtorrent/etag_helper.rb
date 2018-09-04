require_relative 'paged_etag_match_error'
class GHTorrent::EtagHelper
  include GHTorrent::Settings

  EMPTY_RESPONSE_ETAG = '5277b56db38c54d55de2903f41c9f6d6'

  def initialize(command, url, use_etag = true)
    @ght = command.ght
    @url = url
    @use_etag = use_etag
  end

  def request(media_type, paged)
    result = verify_etag_and_get_response(media_type, paged) if first_page? && cacheable_endpoint?
    result ||= @ght.do_request(@url, media_type)
    store_etag_in_db(result, paged) if cacheable_endpoint? && !result.is_a?(String) && cacheable_page?(result.meta['link'])
    result
  rescue PagedEtagMatchError
    # return nil for paged_api_request when response is not modified.
  end

  private

  def verify_etag_and_get_response(media_type, paged)
    etag_data, etag_response = etag_data_and_response(media_type)
    return unless etag_response
    log_etag_usage_and_raise_error(etag_data) if paged && not_modified?(etag_response)
    # For single response & frontloaded api, this value will be 1.
    # For modified backloaded api, this last page response is not useful.
    return unless etag_data[:page_no] == 1
    # Because we would be skipping store_etag_in_db for the String etag_data[:response].
    increment_used_count if not_modified?(etag_response)
    not_modified?(etag_response) ? etag_data[:response] : etag_response
  end

  def cacheable_endpoint?
    return unless @use_etag
    patterns = [%r{/user/(?:search|email)}, %r{/orgs/[^/]+/members},
                %r{/users/[^/]+/orgs}, %r{/compare/.+\.\.\.},
                %r{api.github.com/events},
                %r{/commits/[^/]+$}, %r{/commits\?sha=}]
    patterns.none? { |pattern| @url =~ pattern }
  end

  def etag_data_and_response(media_type)
    etag_data = @ght.db[:etags].first(base_url: base_url) || empty_etag
    return unless etag_data && etag_recently_checked?(etag_data)
    etag_response = get_etag_response(etag_data, media_type)
    [etag_data, etag_response]
  end

  def empty_etag
    return unless base_url =~ %r{/(?:stargazers|forks|pulls|issues)(?:\?state.+)?$}
    { etag: EMPTY_RESPONSE_ETAG, page_no: 1, updated_at: Date.today.prev_day }
  end

  def not_modified?(response)
    response && response.status[0] == '304'
  end

  def first_page?
    current_page_no.to_i == 1
  end

  def current_page_no
    @current_page_no ||= extract_page_no(@url) || 1
  end

  def extract_page_no(string)
    string.slice(/\bpage=(\d+)/, 1)
  end

  def log_etag_usage_and_raise_error(etag_data)
    @ght.db[:etags].where(base_url: base_url)
                   .update(updated_at: Time.now, used_count: etag_data[:used_count] + 1)
    raise PagedEtagMatchError
  end

  def store_etag_in_db(result, paged)
    response_body = get_body_and_rewind(result) unless paged
    params = { base_url: base_url, page_no: current_page_no, updated_at: Time.now,
               etag: result.meta['etag'], response: response_body }

    insert_into_db(params)
  end

  def increment_used_count
    insert_into_db({})
  end

  def insert_into_db(params)
    record = @ght.db[:etags].first(base_url: base_url)
    if record
      attrs = params.merge(used_count: record[:used_count] + 1)
      @ght.db[:etags].where(base_url: base_url).update(attrs)
    else
      @ght.db[:etags].insert(params)
    end
  rescue Sequel::DatabaseError
    @ght.error("Unable to store etag for: #{@url}")
  end

  def get_body_and_rewind(response)
    body = response.read
    response.rewind
    body
  end

  def cacheable_page?(link_headers)
    front_loaded? ? first_page? : last_page?(link_headers)
  end

  # The Link header rel="last" will NOT be present on the last page.
  def last_page?(link_headers)
    link_headers !~ /\; rel="last"/
  end

  def base_url
    return @base_url if @base_url
    base_url = @url.slice(/^[^\?]+/).chomp('/')
    param = '?state=closed' if @url =~ /state=closed/
    @base_url = base_url + param.to_s
  end

  def get_etag_response(etag_data, media_type)
    new_url = modify_page_in_url(etag_data[:page_no])
    @ght.do_request(new_url, media_type, 'If-None-Match' => etag_data[:etag])
  rescue OpenURI::HTTPError => e # 304 response raises an error.
    response = e.io
    raise e unless response.status.first == '304'
    response
  end

  def front_loaded?
    return if base_url =~ %r{/stargazers/?$}
    #               repos/:user/:repo/commits ||                 repos/:user/:repo/pulls/:id/commits
    base_url =~ %r{/repos/[^/]+/[^/]+/\w+/?$} || base_url =~ %r{/repos/[^/]+/[^/]+/\w+/\w+/\w+/?$}
  end

  def modify_page_in_url(page_no)
    page_regexp = /\bpage=\d*/
    if @url.match(page_regexp)
      @url.sub(page_regexp, "page=#{page_no}")
    else
      appender = @url =~ /\?/ ? '&' : '?'
      @url + "#{appender}page=#{page_no}"
    end
  end

  def etag_recently_checked?(etag_data)
    @hours ||= config(:etag_refresh_hours)
    etag_data[:updated_at].to_datetime > (DateTime.now - @hours/24.0)
  end
end
