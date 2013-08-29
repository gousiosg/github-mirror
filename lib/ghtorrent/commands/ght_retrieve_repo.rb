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
    self.settings = override_config(settings, :mirror_history_pages_back, -1)
    user_entry = ght.transaction{ght.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{ARGV[0]}"
    end

    user = user_entry[:login]

    repo_entry = ght.transaction{ght.ensure_repo(ARGV[0], ARGV[1])}

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{ARGV[0]}/#{ARGV[1]}"
    end

    repo = repo_entry[:name]

    def send_message(function, user, repo)
      begin
        ght.send(function, user, repo, refresh = true)
      rescue Exception => e
        puts STDERR, e.message
        puts STDERR, e.backtrace
      end
    end

    functions = %w(ensure_commits ensure_forks ensure_pull_requests
       ensure_issues ensure_project_members ensure_watchers ensure_labels)

    if ARGV[2].nil?
      functions.each do |x|
        send_message(x, user, repo)
      end
    else
      Trollop::die("Not a valid function: #{ARGV[2]}") unless functions.include? ARGV[2]
      send_message(ARGV[2], user, repo)
    end
  end
end

# A version of the GHTorrent class that creates a transaction per processed
# item
class TransactedGHTorrent < GHTorrent::Mirror

  def ensure_commit(repo, sha, user, comments = true)
    check_transaction do
      super(repo, sha, user, comments)
    end
  end

  def ensure_fork(owner, repo, fork_id)
    check_transaction do
      super(owner, repo, fork_id)
    end
  end

  def ensure_pull_request(owner, repo, pullreq_id,
      comments = true, commits = true,
      state = nil, created_at = nil)
    check_transaction do
      super(owner, repo, pullreq_id, comments, commits, state, created_at)
    end
  end

  def ensure_issue(owner, repo, issue_id, events = true, comments = true, labels = true)
    check_transaction do
      super(owner, repo, issue_id, events, comments, labels)
    end
  end

  def ensure_project_member(owner, repo, new_member, date_added)
    check_transaction do
      super(owner, repo, new_member, date_added)
    end
  end

  def ensure_watcher(owner, repo, watcher, date_added = nil)
    check_transaction do
      super(owner, repo, watcher, date_added)
    end
  end

  def ensure_repo_label(owner, repo, name)
    check_transaction do
      super(owner, repo, name)
    end
  end

  def check_transaction(&block)
    begin
      if @db.in_transaction?
        yield block
      else
        transaction do
          yield block
        end
      end
    rescue Exception => e
      puts STDERR, e.message
      puts STDERR, e.backtrace
    end
  end

end