require 'test_helper'

class TestApiUser
  include GHTorrent::APIClient
  attr_accessor :ght, :db
end

describe 'ApiClient' do
  let(:api_client) { TestApiUser.new }
  let(:repo_name) { 'blackducksoftware/ohcount' }

  before do
    api_client.db = db
    api_client.ght = ght
  end

  describe 'api_request' do
    it 'must fetch a github repo successfully' do
      VCR.use_cassette('github_get_repo') do
        url = config[:mirror_urlbase] + 'repos/' + repo_name
        data = api_client.api_request(url)
        data['git_url'].must_match repo_name
      end
    end

    it 'must handle a bad request' do
      url = config[:mirror_urlbase] + 'foo'
      stub_request(:get, url).to_return(body: { message: 'Not Found' }.to_json, status: 404)
      api_client.api_request(url).must_be_empty
    end

    it 'must handle a taken down repo' do
      url = config[:mirror_urlbase] + 'foo'
      stub_request(:get, url).to_return(body: { message: 'DCMA takedown' }.to_json, status: 451)
      api_client.api_request(url).must_be_empty
    end

    it 'must raise an exception when unauthorized request' do
      url = config[:mirror_urlbase] + 'foo'
      stub_request(:get, url).to_return(status: 401)
      -> { api_client.api_request(url) }.must_raise(OpenURI::HTTPError)
    end

    it 'must raise an exception for any other http errors' do
      url = config[:mirror_urlbase] + 'foo'
      stub_request(:get, url).to_return(status: 429)
      api_client.instance_variable_set('@token', '')
      -> { api_client.api_request(url) }.must_raise(OpenURI::HTTPError)
    end

    it 'must catch and raise any ruby errors' do
      Time.any_instance.stubs(:to_ms)
      url = config[:mirror_urlbase] + 'foo'
      stub_request(:get, url).to_return(body: { id: 1 }.to_json)
      -> { api_client.api_request(url) }.must_raise(NoMethodError)
    end

    it 'must open url from the attached server' do
      api_client.instance_variable_set('@attach_ip', '127.0.0.1')
      url = config[:mirror_urlbase] + 'foo'
      stub_request(:get, url).to_return(body: { id: 1 }.to_json)
      api_client.api_request(url)
    end
  end

  describe 'paged_api_request' do
    it 'must fetch a github repo successfully' do
      VCR.use_cassette('github_get_repo') do
        url = config[:mirror_urlbase] + 'repos/' + repo_name
        data = api_client.paged_api_request(url)
        data['git_url'].must_match repo_name
      end
    end

    it 'must combine and return paginated results' do
      VCR.use_cassette('github_get_followers') do
        url = config[:mirror_urlbase] + 'users/notalex/followers?page=1&per_page=3'
        data = api_client.paged_api_request(url)
        data.length.must_equal 9
        data.first['login'].wont_be :empty?
      end
    end

    it 'must paginate as per the pages parameter' do
      VCR.use_cassette('github_get_followers') do
        url = config[:mirror_urlbase] + 'users/notalex/followers?page=1&per_page=3'
        data = api_client.paged_api_request(url, 2)
        data.length.must_equal 6
        data.first['login'].wont_be :empty?
      end
    end

    describe 'must ensure_max_per_page' do
      it 'must set per_page to 100 when page param is present' do
        url = config[:mirror_urlbase] + 'search/repositories?page=1'
        api_client.expects(:api_request_raw).with(url + '&per_page=100', paged: true)
        api_client.paged_api_request(url)
      end
    end
  end

  describe 'num_pages' do
    let(:url) { config[:mirror_urlbase] + 'users/notalex/followers?page=1&per_page=3' }

    it 'must return the number of pages for the response' do
      VCR.use_cassette('github_get_followers') do
        api_client.num_pages(url).must_equal 3
      end
    end

    it 'must return 1 when no response data' do
      stub_request(:get, url)
      api_client.num_pages(url).must_equal 1
    end

    it 'must return 1 when no link header' do
      stub_request(:get, url).to_return(body: 'foo', headers: { foo: 3 })
      api_client.num_pages(url).must_equal 1
    end

    it 'must return 1 when link values are not parsed' do
      stub_request(:get, url).to_return(body: 'foo', headers: { link: :foo })
      api_client.stubs(:parse_links)
      api_client.num_pages(url).must_equal 1
    end
  end
end
