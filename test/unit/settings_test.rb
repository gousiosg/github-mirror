require 'test_helper'

class TestRetriever
  include GHTorrent::Settings
end

describe 'Settings' do
  let(:retriever) { TestRetriever.new }

  describe 'config' do
    it 'must return the value from settings when present' do
      expected_token = Faker::Number.number(5)
      settings = { 'mirror' => { 'token' => expected_token } }
      retriever.stubs(:settings).returns(settings)
      retriever.config(:github_token).must_equal(expected_token)
    end

    it 'must return a DEFAULT value when the key does not exist in settings' do
      retriever.stubs(:settings).returns({})
      retriever.config(:github_token).must_equal(GHTorrent::Settings::DEFAULTS[:github_token])
    end

    it 'must catch exception for missing settings and return default value' do
      retriever.config(:github_token).must_equal(GHTorrent::Settings::DEFAULTS[:github_token])
    end

    it 'must raise exception when use default is false and no settings exists' do
      -> { retriever.config(:github_token, false) }.must_raise(StandardError)
    end
  end

  describe 'merge' do
    it 'must override values in CONFIGKEYS' do
      token = Faker::Internet.password
      retriever.merge(github_token: token)
      TestRetriever::CONFIGKEYS[:github_token].must_equal token
    end
  end

  describe 'override_config' do
    it 'must override a value in the given hash' do
      settings = { 'amqp' => { 'password' => Faker::Internet.password } }
      expected = { 'amqp' => { 'password' => :foo } }
      retriever.override_config(settings, :amqp_password, :foo).must_equal(expected)
    end
  end
end
