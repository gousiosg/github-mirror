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
    fixed = 0
    all = 0
    col.find({"source" => {"$exists"=>1}}).each do |x|
      all += 1
      repo = x['name']
      owner = x['owner']['login']
      source_owner = x['source']['owner']['login']
      source_repo = x['source']['name']
      
      @ght.transaction do
        forked = @ght.ensure_repo(owner, repo, false, false, false)

        source = @ght.ensure_repo(source_owner, source_repo, false, false, false)

        if source.nil?
          puts("Source repo #{source_owner}/#{source_repo} does not exist")
          next
        end

        fork_exists = @ght.get_db[:forks].first(:forked_project_id => forked[:id],
                                                :forked_from_id => source[:id]) 
        if fork_exists.nil?
          fixed += 1
           #@ght.get_db[:forks].insert
          @ght.ensure_forks(source_owner, source_repo)
        end
        puts "Fixed #{fixed}/#{all} forks"
      end
    end 
  end
end

GHTFixForks.run
