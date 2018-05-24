require 'test_helper'

class TestLogging
  include GHTorrent::Logging
  DEFAULTS ||= GHTorrent::Settings::DEFAULTS.dup
end

describe 'Logging' do
  let(:log) { TestLogging.new }
  let(:msg) { Faker::Lorem.sentence }

  it 'should log the error' do
    TestLogging::DEFAULTS[:logging_level] = 'error'
    Logger.any_instance.expects(:error).returns(msg)
    log.error(msg)
  end

  it 'should log the warning' do
    TestLogging::DEFAULTS[:logging_level] = 'warn'
    Logger.any_instance.expects(:warn).returns(msg)
    log.warn(msg)
  end

  it 'should log the information in the logger' do
    Logger.any_instance.expects(:info).returns(msg)
    log.info(msg)
  end

  it 'should log the detail information in the logger' do
    TestLogging::DEFAULTS[:logging_level] = 'debug'
    Logger.any_instance.expects(:debug).returns(msg)
    log.debug(msg)
  end

  it 'should log the message at fatal level' do
    TestLogging::DEFAULTS[:logging_level] = 'fatal'
    Logger.any_instance.expects(:fatal).returns(msg)
    log.send(:log, :fatal, msg)
  end

  it 'should log the message at debug level' do
    Logger.any_instance.expects(:debug).returns(msg)
    log.send(:log, :exception, msg)
  end

  it 'should log to STDERR' do
    TestLogging::DEFAULTS[:logging_file] = 'stderr'
    log.config(:logging_file).stubs(:casecmp).with('stdout').returns(false)
    log.config(:logging_file).stubs(:casecmp).with('stderr').returns(true)
    log.error(msg)
  end

  it 'should log to a file' do
    TestLogging::DEFAULTS[:logging_file] = 'test/log/test.log'
    log.config(:logging_file).stubs(:casecmp).returns(false)
    log.error(msg)
    FileUtils.rm('test/log/test.log')
  end
end
