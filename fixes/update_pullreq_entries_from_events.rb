#!/usr/bin/env ruby

require 'ghtorrent'

class UpdatePullreqEntriesEvents < MultiprocessQueueClient
  def clazz
    UpdatePullRequestHistoryEvents
  end
end

class UpdatePullRequestHistoryEvents

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def initialize(config, queue)
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

  def ext_uniq
    @ext_uniq ||= config(:uniq_id)
    @ext_uniq
  end

  def settings
    @config
  end

  def run(command)
    processor = Proc.new do |event_id|
      @ght ||= GHTorrent::Mirror.new(settings)
      @ght.get_db

      pr = persister.find(:events, {'id' => event_id})[0]

      owner = pr['payload']['pull_request']['base']['repo']['owner']['login']
      repo = pr['payload']['pull_request']['base']['repo']['name']
      pullreq_id = pr['payload']['number']
      action = pr['payload']['action']
      actor = pr['actor']['login']
      created_at = @ght.date(pr['created_at'])

      pullreq_entry = @ght.get_db.from(:pull_requests, :projects, :users)\
                   .where(:users__id => :projects__owner_id)\
                   .where(:projects__id => :pull_requests__base_repo_id)\
                   .where(:users__login => owner)\
                   .where(:projects__name => repo)\
                   .where(:pull_requests__pullreq_id => pullreq_id)\
                   .select(:pull_requests__id).first

      if pullreq_entry.nil?
        logger.warn("Pull req #{owner}/#{repo} -> #{pullreq_id} cannot be found in MySQL")
        next
      end

      begin
        @ght.ensure_pull_request_history(pullreq_entry[:id], created_at,
                                         '', action, actor)

        logger.debug "Processed pull req #{owner}/#{repo} -> #{pullreq_id}\n"
      rescue Exception => e
        logger.warn "Could not process pull req #{owner}/#{repo} -> #{pullreq_id}"
        logger.warn "Reason: #{e}"
      end
    end

    command.queue_client(@queue, :after, processor)
  end
end

UpdatePullreqEntriesEvents.run
