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

  def go
    @ght ||= GHTorrent::Mirror.new(settings)
    col = persister.get_underlying_connection[:repos]
    fixed = tried = all = 0
    col.find({"parent" => {"$exists" => 1}}, {:timeout => false}) do |cursor|
      cursor.each do |x|
        all += 1
        repo = x['name']
        owner = x['owner']['login']
        parent_owner = x['parent']['owner']['login']
        parent_repo = x['parent']['name']

        begin
          @ght.transaction do
            forked = @ght.ensure_repo(owner, repo)
            parent = @ght.ensure_repo(parent_owner, parent_repo)

            if parent.nil?
              puts("parent repo #{parent_owner}/#{parent_repo} does not exist")
              next
            end

            if forked[:forked_from].nil? or forked[:forked_from] != parent[:id]
              tried += 1
              @ght.db[:projects].filter(:id => forked[:id]).update(:forked_from => parent[:id])
              fixed += 1
              puts "Added #{owner}/#{repo} as fork of #{parent_owner}/#{parent_repo}"
            else
              puts "Fork #{owner}/#{repo} of #{parent_owner}/#{parent_repo} exists"
            end

          end
        rescue StandardError => e
          puts "Exception: #{e.message}"
        ensure
          puts "Fixed #{fixed}/#{tried} (examined: #{all}) forks"
        end
      end
    end
  end
end

GHTFixForks.run
