require 'ghtorrent/retriever'
require 'ghtorrent/transacted_gh_torrent'
require 'ghtorrent/commands/full_user_retriever'

# Retrieve user information en masse
class GHTRetrieveUsers < MultiprocessQueueClient

  def clazz
    GHTUserRetriever
  end

end

# Initialize a user retrieval process
class GHTUserRetriever

  include GHTorrent::Retriever
  include GHTorrent::Commands::FullUserRetriever

  attr_accessor :ght

  def initialize(config, queue, options)
    @config = config
    @queue = queue
  end

  def settings
    @config
  end

  def run(command)

    processor = Proc.new do |user|
      @ght ||= TransactedGHTorrent.new(@config)

      retrieve_user(user)
    end

    command.queue_client(@queue, :after, processor)

  end

  def stop
    warn('Stop flag set, waiting for operations to finish')
    @stop = true
  end

end

