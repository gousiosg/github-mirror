require 'test_helper'

class TestRetriever
  include GHTorrent::Geolocator

  def debug(_string)
  end
  alias :info :debug

  def persister
    @persister ||= OpenStruct.new
  end
end

describe 'Geolocator' do
  let(:retriever) { TestRetriever.new }
  let(:location) { 'San Francisco' }

  describe 'OSM_parse_geolocation_result' do
    it 'must store geo location to db' do
      VCR.use_cassette('osm_geolocate') do
        retriever.persister.expects(:find).returns([])
        retriever.persister.expects(:store).once
        data = retriever.geolocate(location: location, from_cache: false)
        data[:country].must_equal 'Philippines'
      end
    end

    it 'must handle empty geo result' do
      VCR.use_cassette('osm_geolocate') do
        retriever.persister.expects(:find).returns([])
        retriever.persister.expects(:store).once
        JSON.stubs(:parse).returns({})
        data = retriever.geolocate(location: location, from_cache: false)
        data.must_equal GHTorrent::Geolocator::EMPTY_LOCATION
      end
    end

    it 'must rescue any errors and set empty location' do
      VCR.use_cassette('osm_geolocate') do
        retriever.persister.expects(:find).returns([])
        retriever.persister.expects(:store).once
        StringIO.any_instance.expects(:read).returns('')
        data = retriever.geolocate(location: location, from_cache: false)
        data.must_equal GHTorrent::Geolocator::EMPTY_LOCATION
      end
    end

    it 'must do nothing when geo exists in db' do
      geo = OpenStruct.new
      retriever.persister.expects(:find).returns([geo])
      retriever.persister.expects(:store).never
      data = retriever.geolocate(location: location, from_cache: true)
      data.must_equal geo
    end
  end

  describe 'bing_parse_geolocation_result' do
    let(:bing_key) { 'dummy_key' }
    before { retriever.stubs(:config).returns(bing_key) }

    it 'must store geo location to db' do
      VCR.use_cassette('bing_geolocate', erb: { bing_key: bing_key }) do
        retriever.persister.expects(:find).returns([])
        retriever.persister.expects(:store).once
        data = retriever.geolocate(location: location, from_cache: false)
        data[:country].must_equal 'United States'
      end
    end

    it 'must handle empty geo result' do
      VCR.use_cassette('bing_geolocate', erb: { bing_key: bing_key }) do
        retriever.persister.expects(:find).returns([])
        retriever.persister.expects(:store).once
        JSON.stubs(:parse).returns({})
        data = retriever.geolocate(location: location, from_cache: false)
        data.must_equal GHTorrent::Geolocator::EMPTY_LOCATION
      end
    end
  end
end
