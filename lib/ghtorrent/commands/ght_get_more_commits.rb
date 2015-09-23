require 'rubygems'
require 'time'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/retriever'

class GHTMoreCommitsRetriever < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister
  include GHTorrent::Logging

  def prepare_options(options)
    options.banner <<-BANNER
Retrieves more commits for the provided repository

#{command_name} [options] owner repo

#{command_name} options:
    BANNER

    options.opt :num, 'Number of commits to retrieve',
                :short => 'n', :default => 1024 * 1024 * 1024, :type => :int
    options.opt :full, 'Retrieve all commits, starting from the latest available.
                        If not set, will start from latest stored commit',
                :short => 'f', :default => false, :type => :boolean
    options.opt :upto, 'Get all commits up to the provided timestamp',
                :short => 'x', :default => 0, :type => :int
  end

  def validate
    super
    Trollop::die "Two arguments are required" unless args[0] && !args[0].empty?
  end

  #def logger
  #  @ght.logger
  #end

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def go

    @ght ||= GHTorrent::Mirror.new(settings)
    user_entry = @ght.transaction{@ght.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{owner}"
    end

    user = user_entry[:login]

    repo_entry = @ght.transaction{@ght.ensure_repo(ARGV[0], ARGV[1])}

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{ARGV[1]}"
    end

    repo = repo_entry[:name]

    head = if options[:full] == false
             @ght.get_db.from(:commits).\
                      where(:commits__project_id => repo_entry[:id]).\
                      order(:created_at).\
                      first[:sha]
           else
             nil
           end

    total_commits = 0
    old_head = nil
    while (true)
      begin
        debug("Retrieving more commits for #{user}/#{repo} from head: #{head}")

        @settings = override_config(@settings, :mirror_history_pages_back, 1)
        commits = retrieve_commits(repo, head, user)

        if commits.nil? or commits.empty? or commits.size == 1
          break
        end

        head = commits.last['sha']

        commits.map do |c|
          total_commits += 1

          if options[:num] < total_commits
            info("Already retrieved #{total_commits} commits. Stopping.")
            return
          end

          if Time.parse(c['commit']['author']['date']) < Time.at(options[:upto])
            info("Commit #{c['sha']} older than #{Time.at(options[:upto])}. Stopping.")
            return
          end

          @ght.transaction do
            @ght.ensure_commit(repo, c['sha'], user)
          end
        end
      rescue Exception => e
        warn("Error processing: #{e}")
        warn(e.backtrace.join("\n"))
        if old_head == head
          info("Commit #{c['sha']} older than #{Time.at(options[:upto])}. Stopping.")
          fail("Cannot retrieve commits from head: #{head}")
        end
        old_head = head
      end
    end
    debug("Processed #{total_commits} commits for #{user}/#{repo}")
  end
end


#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
