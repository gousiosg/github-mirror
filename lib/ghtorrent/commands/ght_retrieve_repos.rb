require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/retriever'
require 'ghtorrent/multiprocess_queue_client'
require "bunny"

class GHTRetrieveRepos < MultiprocessQueueClient

  include GHTorrent::Commands::FullRepoRetriever

  def prepare_options(options)
    super(options)
    supported_options(options)
  end

  def validate
    super
    validate_options
  end

  def clazz
    GHTRepoRetriever
  end

end

class GHTRepoRetriever

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Commands::FullRepoRetriever

  def initialize(config, queue)
    @config = config
    @queue = queue
  end

  def settings
    @config
  end

  def run(command)

    processor = Proc.new do |msg|
      owner, repo = msg.split(/ /)
      retrieve_repo(owner, repo)
    end

    command.queue_client(@queue, :before, processor)
  end

  def stop
    puts('Stop flag set, waiting for operations to finish')
    @stop = true
  end
end

# vim: ft=ruby:
