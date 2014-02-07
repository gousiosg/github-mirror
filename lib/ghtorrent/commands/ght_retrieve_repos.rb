require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/retriever'
require 'ghtorrent/multiprocess_queue_client'
require "bunny"

class GHTRetrieveRepos < MultiprocessQueueClient

  def clazz
    GHTRepoRetriever
  end

end

class GHTRepoRetriever

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def initialize(config, queue)
    @config = config
    @queue = queue
  end

  def logger
    ght.logger
  end

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def ext_uniq
    @ext_uniq ||= config(:uniq_id)
    @ext_uniq
  end

  def ght
    @ght ||= TransactedGhtorrent.new(@config)
    @ght
  end

  def settings
    @config
  end

  def run(command)

    processor = Proc.new do |msg|
      owner, repo = msg.split(/ /)
      user_entry = ght.transaction { ght.ensure_user(owner, false, false) }

      if user_entry.nil?
        warn("Cannot find user #{owner}")
        next
      end

      repo_entry = ght.transaction { ght.ensure_repo(owner, repo) }

      if repo_entry.nil?
        warn("Cannot find repository #{owner}/#{repo}")
        next
      end

      debug("Retrieving repo #{owner}/#{repo}")

      def send_message(function, user, repo)
        ght.send(function, user, repo, refresh = false)
      end

      functions = %w(ensure_commits ensure_forks ensure_pull_requests
            ensure_issues ensure_project_members ensure_watchers ensure_labels)

      functions.each do |x|

        begin
          send_message(x, owner, repo)
        rescue Exception
          warn("Error processing #{x} for #{owner}/#{repo}")
          next
        end
      end
    end

    command.queue_client(@queue, :before, processor)
  end

  def stop
    warn('Stop flag set, waiting for operations to finish')
    @stop = true
  end
end

