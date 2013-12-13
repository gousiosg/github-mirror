require 'rspec'
require 'webmock/rspec'

require 'ghtorrent'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def settings
  YAML::load_file('config.yaml')
end

def logger
  Logger.new(STDERR)
end
