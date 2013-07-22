#!/usr/bin/env ruby

require 'ghtorrent'
require 'parallel'

class GHTFixPullReqCommits2 < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def prepare_options(options)
    options.banner <<-BANNER
Fixes issues with multiple commits in pull requests
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

    col = persister.get_underlying_connection.collection(:pull_requests.to_s)

    add = rm = proc = failed = 0
    col.find({}, {:timeout => false}) do |cursor|
      cursor.each do |pr|
        owner = pr['base']['repo']['owner']['login']
        repo = pr['base']['repo']['name']
        number = pr['number']
        begin
          ght.transaction do
            proc += 1
            puts "#{owner}/#{repo} -> #{number} processing"
            result = fix_pull_request(pr)
            rm += result[:rm]
            add += result[:add]

            STDERR.write "processed: #{proc} removed #{rm} added #{add} failed #{failed}"
          end
        rescue Exception => e
          failed += 1
          puts e.message
          #raise e
        end
      end
    end
  end

  def db
    @db ||= ght.get_db
    @db
  end

  def fix_pull_request(pr)
    pull_req = ght.ensure_pull_request(pr['owner'], pr['repo'], pr['number'],
                                       false, false, false)

    if pull_req.nil?
      return
    end

    commits = retrieve_pull_req_commits(pr['owner'], pr['repo'], pr['number'])

    if commits.empty?
      return
    end

    commit_ids = commits.map do |x|
      url = x['url'].split(/\//)
      c = ght.ensure_commit(url[5], url[7], url[4])

      if c.nil? then next else c[:id] end
    end

    rm = db[:pull_request_commits].where(:pull_request_id => pull_req[:id]).delete()

    add = commit_ids.map do |x|
      db[:pull_request_commits].insert(
          :pull_request_id => pull_req[:id],
          :commit_id => x
      )
    end.size

    {:rm => rm, :add => add}
  end
end

GHTFixPullReqCommits2.run
