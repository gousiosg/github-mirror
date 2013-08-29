#!/usr/bin/env ruby

require 'ghtorrent'

class GHTUpdatePullRequestHistoryActor < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister


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


  def go
    @ght ||= GHTorrent::Mirror.new(settings)
    col = persister.get_underlying_connection.collection(:events.to_s)

    @ght.get_db
    prs = 0

    query = if ARGV[0].nil? then {'type' => 'PullRequestEvent'}
            else {'type' => 'PullRequestEvent', 'id' => ARGV[0]} end

    col.find(query, {:timeout => false}) do |cursor|
      cursor.each do |pr|
        prs += 1

        owner = pr['payload']['pull_request']['base']['repo']['owner']['login']
        repo = pr['payload']['pull_request']['base']['repo']['name']
        pullreq_id = pr['payload']['number']
        action = pr['payload']['action']
        actor = pr['actor']['login']
        created_at = pr['created_at']

        begin
          @ght.get_pull_request(owner, repo, pullreq_id, action, actor, created_at)
          STDERR.write "Processed pull req #{owner}/#{repo} -> #{pullreq_id}\n"
        rescue Exception => e
          logger.debug "Could not process pull req #{owner}/#{repo} -> #{pullreq_id}"
          logger.debug "Reason: #{e}"
        end
      end
    end
  end

end

GHTUpdatePullRequestHistoryActor.run
