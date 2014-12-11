require 'rubygems'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
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
    self.settings = override_config(settings, :mirror_history_pages_back, 1000)
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
      ght.send(function, user, repo)
    end

    functions = %w(ensure_commits ensure_forks ensure_pull_requests
       ensure_issues ensure_watchers ensure_labels) #ensure_project_members

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

