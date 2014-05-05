#!/usr/bin/env ruby

require 'ghtorrent'

class GHTFixPullReqCommits < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def prepare_options(options)
    options.banner <<-BANNER
Fixes issue where pull request commits where accidentally stored as
base repo commits even if the pull request was not merged. Only run it
if you have used GHTorrent in version < 0.7
#{command_name} [repo owner]

If a repo and owner are provided, the fix will only happen for the pull requests
in the provided project.
    BANNER
  end

  def validate
    super
    Trollop::die "Either takes no arguments or two" if ARGV.size == 1
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
    @ght ||= GHTorrent::Mirror.new(settings)
    @ght
  end

  def project
    "#{@owner}/#{@repo}"
  end

  def go

    filter = if ARGV.size == 2
               self.settings = override_config(settings, :mirror_history_pages_back, -1)
               user_entry = ght.transaction { ght.ensure_user(ARGV[0], false, false) }

               if user_entry.nil?
                 Trollop::die "Cannot find user #{ARGV[0]}"
               end

               repo_entry = ght.transaction{ ght.ensure_repo(ARGV[0], ARGV[1]) }

               if repo_entry.nil?
                 Trollop::die "Cannot find repository #{ARGV[0]}/#{ARGV[1]}"
               end
               {"owner" => ARGV[0], "repo" => ARGV[1]}
             else
               {}
             end

    col = persister.get_underlying_connection.collection(:pull_requests.to_s)
    col.find(filter, {:timeout => false}) do |cursor|
      cursor.each do |pr|
        @owner = pr['base']['repo']['owner']['login']
        @repo = pr['base']['repo']['name']
        number = pr['number']
        begin
          ght.transaction do
            dbg number, "processing"
            fix_pull_request(pr)
          end
        rescue Exception => e
          #raise e
          dbg number, e.message
        end
      end
    end
    ght.ensure_commits(@owner, @repo, nil, 100)
  end

  def db
    @db ||= ght.get_db
    @db
  end

  def dbg(pr_id, msg)
    puts "FIXPRC: project: #{project} pr: #{pr_id} #{msg}"
  end

  def fix_pull_request(pr)
    pullreq_id = pr['number']
    if pr['head']['repo'].nil?
      head_owner = head_repo = nil
    else
      head_owner = pr['head']['repo']['owner']['login']
      head_repo = pr['head']['repo']['name']
    end

    base_owner = pr['base']['repo']['owner']['login']
    base_repo = pr['base']['repo']['name']

    commits = retrieve_pull_req_commits(base_owner, base_repo, pullreq_id)
    commits.each do |c|

      if c.nil?
        dbg pullreq_id, "Commit is null?"
        next
      end

      commit_repo_owner = c['url'].split(/\//)[4]
      commit_repo_name = c['url'].split(/\//)[5]

      desgignated_repo_owner = db[:users].first(:login => commit_repo_owner)
      designated_repo = db[:projects].first(
          :owner_id => desgignated_repo_owner[:id], :name => commit_repo_name)

      if designated_repo.nil?
        if head_repo.nil?
          dbg pullreq_id, "head repo: #{commit_repo_owner}/#{commit_repo_name} deleted"
        else
          dbg pullreq_id, "not processed yet, skipping"
          next
        end
      end

      db_commit = db[:commits].first(:sha => c['sha'])

      if db_commit.nil?
        dbg pullreq_id, "commit: #{c['sha']} not in database yet"
        next
      end

      actual_repo = db[:projects].first(:id => db_commit[:project_id])

      if designated_repo.nil?
        db[:commits].filter(:sha => c['sha']).update(:project_id => nil)
      elsif actual_repo.nil?
        dbg pullreq_id, "commit: #{c['sha']} -> wrong owning repo" +
            " nil, should be" +
            " #{commit_repo_owner}/#{designated_repo[:name]}"
        db[:commits].filter(:sha => c['sha']).update(:project_id => designated_repo[:id])
      elsif designated_repo[:id] != actual_repo[:id]
        actual_repo_owner = db[:users].first(:id => actual_repo[:owner_id])
        dbg pullreq_id, "commit: #{c['sha']} -> wrong owning repo" +
            " #{actual_repo_owner[:login]}/#{actual_repo[:name]}, should be" +
            " #{commit_repo_owner}/#{designated_repo[:name]}"
        db[:commits].filter(:sha => c['sha']).update(:project_id => designated_repo[:id])
      end
      db[:project_commits].where(:commit_id => db_commit[:id]).delete

    end
    ght.ensure_pull_request(base_owner, base_repo, pullreq_id)
  end
end

GHTFixPullReqCommits.run
