#!/usr/bin/env ruby

require 'ghtorrent'

class GHTFixForks < GHTorrent::Command

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
    col = persister.get_underlying_connection.collection(:repos.to_s)
    fixed = tried = all = 0
    col.find({"source" => {"$exists" => 1}}, {:timeout => false}) do |cursor|
      cursor.each do |x|
        all += 1
        repo = x['name']
        owner = x['owner']['login']
        source_owner = x['source']['owner']['login']
        source_repo = x['source']['name']

        begin
          @ght.transaction do
            fork = @ght.ensure_repo(owner, repo, false, false, false)

            source = @ght.ensure_repo(source_owner, source_repo, false, false, false)

            if source.nil?
              puts("Source repo #{source_owner}/#{source_repo} does not exist")
              next
            end

            fork_exists = @ght.get_db[:forks].first(:forked_project_id => fork[:id],
                                                    :forked_from_id => source[:id])
            if fork_exists.nil?
              @ght.ensure_forks(source_owner, source_repo)
              tried += 1
              fork_exists = @ght.get_db[:forks].first(:forked_project_id => fork[:id],
                                                      :forked_from_id => source[:id])
              if fork_exists.nil?
                puts "Could not find fork #{owner}/#{repo} of #{source_owner}/#{source_repo}"
              else
                puts "Added fork #{owner}/#{repo} of #{source_owner}/#{source_repo}"
                fixed += 1
              end
            end
            puts "Fixed #{fixed}/#{tried} (examined: #{all}) forks"
          end
        rescue Exception => e
          puts "Exception: #{e.message}"
        end
      end
    end
  end
end

GHTFixForks.run
