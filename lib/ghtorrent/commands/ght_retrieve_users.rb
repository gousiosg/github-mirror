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

  def initialize(config, queue, options)
    @config = config
    @queue = queue
    @options = options
  end

  def settings
    @config
  end

  def run(command)

    processor = Proc.new do |user|
      retrieve_user(user)
    end

    command.queue_client(@queue, GHTorrent::ROUTEKEY_USERS, :after, processor)

  end

  def stop
    warn('Stop flag set, waiting for operations to finish')
    @stop = true
  end

end

