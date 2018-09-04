require 'test_helper'

class TestRetriever
  include GHTorrent::APIClient
  attr_accessor :ght, :db
end

EtagHelper = GHTorrent::EtagHelper

describe 'EtagHelper' do
  let(:command) { stub(ght: ght) }
  before { EtagHelper.any_instance.unstub(:cacheable_endpoint?) }

  describe 'first_page' do
    it 'must be truthy for the first page' do
      ['url?per_page=2&page=',
       'url?per_page=2&page=1',
       'url?per_page=2&page=&var=2',
       'url?per_page=2&page=1&var=2',
       'url?page=&per_page=2',
       'url?page=1&per_page=2'].each do |url|
        EtagHelper.new(command, url).send(:first_page?).must_equal true
      end

      ['url', 'url?per_page=1'].each do |url|
        EtagHelper.new(command, url).send(:first_page?).must_equal true
      end
    end

    it 'must be false for non first pages' do
      ['url?page=0&per_page=2',
       'url?per_page=2&page=2',
       'url?per_page=2&page=21',
       'url?per_page=2&page=11&var=2'].each do |url|
        EtagHelper.new(command, url).send(:first_page?).must_equal false
      end
    end
  end

  describe 'front_loaded' do
    it 'must be true for all repos/alphanum/alphanum/alphanum patterns except stargazers' do
      ["https://api.github.com/repos/foo/bar/#{Faker::Lorem.word}?x=y&z=o",
       'https://api.github.com/repos/foo/bar/pulls/42/commits',
       'https://api.github.com/repos/foo/bar/comm1ts/'].each do |url|
        EtagHelper.new(command, url).send(:front_loaded?).wont_be_nil
      end

      ['https://api.github.com/repos/foo/bar/stargazers?per_page=2&page=2',
       'https://api.github.com/repos/foo/bar/@commits',
       'https://api.github.com/repos/foo/bar/commits/eb6ba57'].each do |url|
        EtagHelper.new(command, url).send(:front_loaded?).must_be_nil
      end
    end
  end

  describe 'request' do
    run_tests_in_transaction
    let(:retriever) { TestRetriever.new }
    let(:media_type) { 'application/json' }

    before do
      retriever.db = db
      retriever.ght = ght
      retriever.stubs(:auth_method).returns(:none)
    end

    describe 'frontloaded apis' do
      it 'must save the ETag for the first page' do
        url = 'https://api.github.com/repos/blackducksoftware/ohcount/events?page=1&per_page=2'

        VCR.use_cassette('github_etags_front_loaded') do
          assert_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            etag_helper.request(media_type, true)
            db[:etags].first(base_url: etag_helper.send(:base_url))[:response].must_be_nil
          end
        end
      end

      it 'must update existing ETag when its value is changed on Github' do
        url = 'https://api.github.com/repos/blackducksoftware/ohcount/events?per_page=2'
        etag = Faker::Internet.password
        base_url = url.slice(/^[^\?]+/)
        db[:etags].insert(base_url: base_url, etag: etag, page_no: 1)

        VCR.use_cassette('github_etags_front_loaded') do
          assert_no_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            etag_helper.request(media_type, true)
            db[:etags].first(base_url: base_url)[:etag].wont_equal etag
          end
        end
      end

      it 'wont save ETag for intermediate pages' do
        url = 'https://api.github.com/repos/blackducksoftware/ohcount/events?page=2&per_page=2'

        stub_request(:get, url)
        assert_no_difference 'db[:etags].count' do
          etag_helper = EtagHelper.new(retriever, url)
          etag_helper.request(media_type, true)
        end
      end

      it 'must return nil and increment etag used_count on requery' do
        url = 'https://api.github.com/repos/blackducksoftware/ohcount/events?page=1&per_page=2'
        etag = %(W/"c483d6f23e912a62cb1ae11316662174")
        base_url = url.slice(/^[^\?]+/)
        db[:etags].insert(base_url: base_url, etag: etag, page_no: 1)

        VCR.use_cassette('github_etags_front_loaded_not_modified') do
          assert_no_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            response = etag_helper.request(media_type, true)
            response.must_be_nil
            etag_data = db[:etags].first(base_url: base_url)
            etag_data[:etag].must_equal etag
            etag_data[:used_count].must_equal 1
          end
        end
      end
    end

    describe 'single response api' do
      it 'must save the ETag and response body' do
        url = 'https://api.github.com/repos/blackducksoftware/ohcount'

        VCR.use_cassette('github_etags_single_response') do
          assert_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            etag_helper.request(media_type, false)
            db[:etags].first(base_url: url)[:response].wont_be_nil
          end
        end
      end

      it 'must update existing ETag when its value is changed on Github' do
        url = 'https://api.github.com/repos/blackducksoftware/ohcount'
        etag = Faker::Internet.password
        base_url = url.slice(/^[^\?]+/)
        db[:etags].insert(base_url: base_url, etag: etag)

        VCR.use_cassette('github_etags_single_response', match_requests_on: [:path]) do
          assert_no_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            etag_helper.request(media_type, true)
            db[:etags].first(base_url: base_url)[:etag].wont_equal etag
          end
        end
      end

      it 'must return stored response and increment etag used_count on requery' do
        url = 'https://api.github.com/repos/blackducksoftware/ohcount'
        etag = %(W/"f0b86042f3e999720dec791ca6123b8e")
        base_url = url.slice(/^[^\?]+/)
        db[:etags].insert(base_url: base_url, etag: etag, response: '{"id":42,"url"}')

        VCR.use_cassette('github_etags_single_not_modified') do
          assert_no_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            response = etag_helper.request(media_type, false)
            response.is_a?(String).must_equal true
            etag_data = db[:etags].first(base_url: base_url)
            etag_data[:etag].must_equal etag
            etag_data[:used_count].must_equal 1
          end
        end
      end
    end

    describe 'backloaded apis' do
      it 'must save the ETag for the last page' do
        url = 'https://api.github.com/users/linus/followers?page=43&per_page=2'

        VCR.use_cassette('github_etags') do
          assert_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            etag_helper.expects(:get_etag_response).never
            etag_helper.request(media_type, true)
          end
        end
      end

      it 'must update existing ETag when its value is changed on Github' do
        url = 'https://api.github.com/users/linus/followers?page=43&per_page=2'
        etag = Faker::Internet.password
        base_url = url.slice(/^[^\?]+/)
        db[:etags].insert(base_url: base_url, etag: etag, page_no: 43)

        VCR.use_cassette('github_etags') do
          assert_no_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            etag_helper.request(media_type, true)
            db[:etags].first(base_url: base_url)[:etag].wont_equal etag
          end
        end
      end

      it 'must return nil and increment etag used_count on requery' do
        # First request to start pagination will have no page number.
        url = 'https://api.github.com/users/linus/followers?per_page=2'
        etag = %(W/"7e96712c73e285b2d348146921ccc000")
        base_url = url.slice(/^[^\?]+/)
        db[:etags].insert(base_url: base_url, etag: etag, page_no: 44)

        VCR.use_cassette('github_etags_not_modified') do
          assert_no_difference 'db[:etags].count' do
            etag_helper = EtagHelper.new(retriever, url)
            response = etag_helper.request(media_type, true)
            response.must_be_nil
            etag_data = db[:etags].first(base_url: base_url)
            etag_data[:etag].must_equal etag
            etag_data[:used_count].must_equal 1
          end
        end
      end
    end

    describe 'non cacheable endpoints' do
      it 'wont call etag related methods' do
        urls = %w(https://api.github.com/users/foobar/orgs
                  https://api.github.com/repos/foo/bar/commits?sha=eb6ba57
                  https://api.github.com/repos/foo/bar/commits/eb6ba57
                  https://api.github.com/repos/foo/bar/compare/master...foo:develop
                  https://api.github.com/legacy/user/email/foo
                  https://api.github.com/legacy/user/search/foo)

        ght.stubs(:do_request).returns(stub(meta: {}))

        urls.each do |url|
          etag_helper = EtagHelper.new(retriever, url)
          etag_helper.expects(:get_etag_response).never
          etag_helper.expects(:store_etag_in_db).never
          etag_helper.request(media_type, false)
        end
      end
    end

    describe 'use_etag is false' do
      it 'wont call etag related methods' do
        url = 'https://api.github.com/repo/foo/bar'
        ght.stubs(:do_request).returns(stub(meta: {}))
        etag_helper = EtagHelper.new(retriever, url, false)
        etag_helper.expects(:etag_data_and_response).never
        etag_helper.expects(:store_etag_in_db).never
        etag_helper.request(media_type, false)
      end
    end
  end

  describe 'base_url' do
    it 'must retain the state query param only' do
      expected_base_url = 'https://api.github.com/repos/foo/bar/pulls?state=closed'
      url = expected_base_url + '&foobar=2'

      etag_helper = EtagHelper.new(command, url)
      etag_helper.send(:base_url).must_equal expected_base_url

      new_url = 'https://api.github.com/repos/foo/bar/pulls?foobar=n&state=closed'
      etag_helper = EtagHelper.new(command, new_url)
      etag_helper.send(:base_url).must_equal expected_base_url
    end
  end

  describe 'etag_data_and_response' do
    it 'must return a static empty etag object on first run for certain endpoints' do
      url = 'https://api.github.com/repos/foo/bar/pulls'
      retriever = TestRetriever.new
      retriever.ght = ght
      etag_helper = EtagHelper.new(retriever, url)
      expected_etag = { etag: EtagHelper::EMPTY_RESPONSE_ETAG, page_no: 1, updated_at: Date.today.prev_day }
      etag_helper.expects(:get_etag_response)
      response = etag_helper.send(:etag_data_and_response, '')
      response.must_equal [expected_etag, nil]
    end
  end

  describe 'etag_recently_checked?' do
    before { EtagHelper.any_instance.unstub(:etag_recently_checked?) }
    it 'must return an empty response when etag has been recently checked' do
      url = 'https://api.github.com/repos/foo/bar/pulls'
      retriever = TestRetriever.new
      retriever.ght = ght
      etag_helper = EtagHelper.new(retriever, url)
      expected_etag = { etag: EtagHelper::EMPTY_RESPONSE_ETAG, page_no: 1, updated_at: DateTime.now}
      etag_helper.expects(:get_etag_response).never
      response = etag_helper.send(:etag_data_and_response, '')
      refute response
    end
  end
end
