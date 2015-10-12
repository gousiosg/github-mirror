#!/usr/bin/env ruby

require 'ghtorrent'

# Update repos en masse
class GHTUpdateRepos < MultiprocessQueueClient
  def clazz
    GHTRepoUpdater
  end
end

# Initialize a repo update process
class GHTRepoUpdater

  include GHTorrent::Logging
  include GHTorrent::Commands::RepoUpdater

  def initialize(config, queue, options)
    @config = config
    @queue = queue
    @options = options
  end

  def settings
    @config
  end

  def run(command)

    processor = Proc.new do |msg|
      owner, repo = msg.split(/ /)
      process_project(owner, repo)
    end

    command.queue_client(@queue, GHTorrent::ROUTEKEY_PROJECTS, :after, processor)

  end

  def stop
    warn('Stop flag set, waiting for operations to finish')
    @stop = true
  end

end

