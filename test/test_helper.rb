require 'simplecov'
require 'simplecov-rcov'
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start
SimpleCov.minimum_coverage 85

require 'vcr'
VCR.configure do |config|
  config.cassette_library_dir = 'fixtures/vcr_cassettes'
  config.hook_into :webmock
end

require 'minitest/autorun'
require 'ghtorrent'
require 'mocha/minitest'
require 'webmock/minitest'
require 'factory_girl'
require 'faker'
require 'byebug'
require 'helpers/shared'
require 'helpers/minitest_trx'
require 'helpers/assert_difference'
require 'minitest/around/spec'

FactoryGirl.find_definitions
include FactoryGirl::Syntax::Methods

class MiniTest::Spec
  before do
    GHTorrent::EtagHelper.any_instance.stubs(:cacheable_endpoint?)
    GHTorrent::EtagHelper.any_instance.stubs(:etag_recently_checked?).returns true
  end
end
