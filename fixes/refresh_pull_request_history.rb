#!/usr/bin/env ruby

require 'ghtorrent'

class GHTRefreshPullReqHistory < MultiprocessQueueClient

  def clazz
    RefreshPullReqHistory
  end

end

class RefreshPullReqHistory

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister
  include GHTorrent::APIClient

  def initialize(config, queue, options)
    @config = config
    @queue = queue
  end

  def logger
    @ght.logger
  end

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def settings
    @config
  end

  def validate
    super
    Trollop::die 'Three arguments required' unless args[2] && !args[2].empty?
  end

  def run(command)

    processor = Proc.new do |msg|

      owner, repo, pull_req = msg.split(/ /)

      @ght ||= GHTorrent::Mirror.new(settings)
      col = persister.get_underlying_connection[:pull_requests]

      retrieved = api_request("https://api.github.com/repos/#{owner}/#{repo}/pulls/#{pull_req}")

      if retrieved.nil?
        log.warn("Cannot retrieve #{owner}/#{repo} -> #{pull_req}")
        return
      end

      retrieved['owner'] = owner
      retrieved['repo'] = repo
      retrieved['number'] = pull_req.to_i

      col.delete_one({'owner' => owner, 'repo' => repo, 'number' => pull_req.to_i})
      col.insert_one(retrieved)

      @ght.get_db.from(:pull_request_history, :pull_requests, :users, :projects)\
                 .where(:pull_requests__id => :pull_request_history__pull_request_id)\
                 .where(:users__id => :projects__owner_id)\
                 .where(:projects__id => :pull_requests__base_repo_id)\
                 .where(:users__login => owner)\
                 .where(:projects__name => repo)\
                 .where(:pull_requests__pullreq_id => pull_req)\
                 .delete

      @ght.ensure_pull_request(owner, repo, pull_req,
                               comments = false, commits = false, history = true)
  end

  command.queue_client(@queue, :after, processor)
  end

end

GHTRefreshPullReqHistory.run
