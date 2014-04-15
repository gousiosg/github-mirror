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

      # On rare occasions, 2 instances might try to add the same user
      # at the same time, which might lead to transaction conflicts
      # Give the script one more opportunity before bailing out
      user_entry = nil
      i = 0

      while user_entry.nil? and i < 10 do
        i += 1
        warn("Trying to get user #{owner}, attempt #{i}")
        begin
          user_entry = ght.transaction { ght.ensure_user(owner, false, false) }
        rescue Exception => e
          warn e.message
        end
      end

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

      retrieval_stages = %w(ensure_commits ensure_forks ensure_pull_requests
            ensure_issues ensure_project_members ensure_watchers ensure_labels)

      retrieval_stages.each do |x|
        run_retrieval_stage(ght, owner, repo, x)
      end

      # Repository owner bound data retrieval
      run_retrieval_stage(ght, owner, repo, 'ensure_user_followers', onlyuser = true)

      if user_entry[:type] == 'ORG'
        run_retrieval_stage(ght, owner, repo, 'ensure_org', onlyuser = true)
      end
    end

    command.queue_client(@queue, :before, processor)
  end

  def run_retrieval_stage(ght, owner, repo, function, only_user = false)
    begin
      if only_user
        ght.send(function, owner)
      else
        ght.send(function, owner, repo, refresh = false)
      end
    rescue Exception => e
      warn("Error processing #{function} for #{owner}/#{repo}")
      warn("Exception message #{$!}")
      warn("Exception trace #{e.backtrace.join("\n")}")
    end
  end

  def stop
    warn('Stop flag set, waiting for operations to finish')
    @stop = true
  end
end

# vim: ft=ruby:
