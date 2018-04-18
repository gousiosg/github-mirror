require 'simplecov'
require 'simplecov-rcov'
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start 
# SimpleCov.minimum_coverage 96.3


require 'minitest/autorun'
require 'ghtorrent'
require 'mocha/mini_test'
require 'factory_girl'
require 'faker'
require 'byebug'

FactoryGirl.find_definitions




