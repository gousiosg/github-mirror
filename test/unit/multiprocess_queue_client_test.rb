require 'test_helper'

class TestClientRetriever
  def initialize(conf, queue, options)
  end
end

class TestProcessClient < MultiprocessQueueClient
  attr_reader :exit

  def clazz
    TestClientRetriever
  end
end

describe 'MultiprocessQueueClient' do
  let(:client) { TestProcessClient.new }

  describe 'go' do
    it 'must call run on the retriever with correct config' do
      token = Faker::Internet.password
      process_count = 3
      mapping_file = <<-DOC.gsub(/^\s+/, '')
        # TOKEN NUM_PROCS LIMIT

        #{Faker::Internet.password} #{process_count} 24

      DOC
      settings = { 'mirror' => { 'token' => token, 'req_limit' => 10 } }
      client.stubs(:settings).returns(settings)
      client.stubs(:options).returns({ inproc: true })
      File.stubs(:open).returns(stub(readlines: mapping_file.split(/\n/)))
      TestClientRetriever.any_instance.stubs(:stop)
      Process.stubs(:waitpid)

      TestClientRetriever.any_instance.expects(:run).at_least(process_count)

      client.go
    end

    it 'must fork a subprocess when inproc is false' do
      mapping_file = <<-DOC.gsub(/^\s+/, '')
        # TOKEN NUM_PROCS LIMIT

        #{Faker::Internet.password} 2 24

      DOC
      settings = { 'mirror' => { 'token' => Faker::Internet.password, 'req_limit' => 10 } }
      client.stubs(:settings).returns(settings)
      client.stubs(:options).returns({ inproc: false })
      File.stubs(:open).returns(stub(readlines: mapping_file.split(/\n/)))
      TestClientRetriever.any_instance.stubs(:stop)
      TestClientRetriever.stubs(:run)

      pid = Faker::Number.number(2)
      Process.expects(:fork).returns(pid).twice
      Process.expects(:waitpid).with(pid, 0).twice

      client.go
    end
  end

  describe 'validate' do
    it 'must call trolltop.die' do
      GHTorrent::Command.any_instance.expects(:validate)
      Optimist.expects(:die)

      client.stubs(:args).returns([])
      client.validate
    end
  end
end
