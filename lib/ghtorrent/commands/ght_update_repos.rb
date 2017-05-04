#!/usr/bin/env ruby

require 'ghtorrent'

# Update repos en masse
class GHTUpdateRepos < MultiprocessQueueClient

  def prepare_options(options)
    super(options)
    options.opt :commits, 'Retrieve commits for repo', :default => false
  end

  def validate
    super
  end

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

      if @options[:commits_given]
        ght = get_mirror_class.new(settings)
        ght.ensure_commits(owner, repo)
      end
    end

    command.queue_client(@queue, GHTorrent::ROUTEKEY_PROJECTS, :after, processor)

  end

  def stop
    warn('Stop flag set, waiting for operations to finish')
    @stop = true
  end

end

