require 'rubygems'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/retriever'

class GHTRetrieveRepo < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def prepare_options(options)
    options.banner <<-BANNER
An efficient way to get all data for a single repo

#{command_name} [options] owner repo

    BANNER
  end

  def validate
    super
    Trollop::die "Two arguments are required" unless args[0] && !args[0].empty?
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
    @ght ||= TransactedGHTorrent.new(settings)
    @ght
  end

  def go
    user_entry = ght.transaction{ght.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{owner}"
    end

    user = user_entry[:login]

    repo_entry = ght.transaction{ght.ensure_repo(ARGV[0], ARGV[1], false, false, false)}

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{ARGV[1]}"
    end

    repo = repo_entry[:name]

    %w(ensure_commits ensure_forks ensure_pull_requests
       ensure_issues ensure_project_members ensure_watchers).each {|x|
      begin
        ght.send(x, user, repo)
      rescue Exception => e
        puts STDERR e.message
        puts STDERR e.backtrace
      end
    }
  end
end

# A version of the GHTorrent class that creates a transaction per processed
# item
class TransactedGHTorrent < GHTorrent::Mirror

  def ensure_commit(repo, sha, user, comments = true)
    transaction do
      super(repo, sha, user, comments)
    end
  end

  def ensure_fork(owner, repo, fork_id, date_added = nil)
    transaction do
      super(owner, repo, fork_id, date_added)
    end
  end

  def ensure_pull_request(owner, repo, pullreq_id,
      comments = true, commits = true,
      state = nil, created_at = nil)
    transaction do
      super(owner, repo, pullreq_id, comments, commits, state, created_at)
    end
  end

  def ensure_issue(owner, repo, issue_id, events = true, comments = true)
    transaction do
      super(owner, repo, issue_id, events, comments)
    end
  end

  def ensure_project_member(owner, repo, new_member, date_added)
    transaction do
      super(owner, repo, new_member, date_added)
    end
  end

  def ensure_watcher(owner, repo, watcher, date_added = nil)
    transaction do
      super(owner, repo, watcher, date_added)
    end
  end
end