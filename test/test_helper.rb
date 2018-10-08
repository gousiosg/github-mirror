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
require 'minitest/around/spec'

FactoryGirl.find_definitions
include FactoryGirl::Syntax::Methods
