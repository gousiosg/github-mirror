#!/usr/bin/env ruby

require 'ghtorrent'

class GHTUpdateRepo < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister
  include GHTorrent::Logging

  def prepare_options(options)
    options.banner <<-BANNER
Updates the deleted field in the project table with current data

#{command_name} owner repo

    BANNER
  end

  def validate
    super
    Trollop::die "Takes two arguments" if ARGV.size == 1
  end

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def db
    @db ||= @ght.get_db
  end

  def date(arg)
    if arg.class != Time
      Time.parse(arg)#.to_i
    else
      arg
    end
  end

  def set_deleted(owner, repo)
    db.from(:projects, :users).\
       where(:projects__owner_id => :users__id).\
       where(:users__login => owner).\
       where(:projects__name => repo).\
       update(:projects__deleted => true)
    info("Project #{owner}/#{repo} marked as deleted")
  end

  def update_mysql(owner, repo, retrieved)

    parent = unless retrieved['parent'].nil?
               @ght.ensure_repo(retrieved['parent']['owner']['login'],
                                retrieved['parent']['name'])
             end

    db.from(:projects, :users).\
       where(:projects__owner_id => :users__id).\
       where(:users__login => owner).\
       where(:projects__name => repo).\
       update(
         :projects__url => retrieved['url'],
         :projects__description => retrieved['description'],
         :projects__language => retrieved['language'],
         :projects__created_at => date(retrieved['created_at']),
         :projects__forked_from => unless parent.nil? then parent[:id] end)
    debug("Repo #{owner}/#{repo} updated")

    @ght.ensure_languages(owner, repo)
  end

  def process_project(owner, name)
    @ght.transaction do

      in_mongo = persister.find(:repos, {'owner.login' => owner, 'name' => name })
      on_github = api_request(ghurl ("repos/#{owner}/#{name}"))

      unless in_mongo.empty? and on_github.empty?
        in_mysql = retrieve_repo(owner, name)
      end

      if in_mongo.empty?
        if on_github.empty?
          if in_mysql.nil?
            # Project does not exist anywhere
            warn "Repo #{owner}/#{name} does not exist in MySQL"
          else
            # Project exists in MySQL but not on Github or Mongo
            # Mark it as deleted
            set_deleted(owner, name)
          end
        else
          # Project does not exist in Mongo, but exists in Github
          if in_mysql.nil?
            warn "Repo #{owner}/#{name} does not exist in MySQL"
          else
            # The retrieval process already added it to Mongo, so update MySQL
            update_mysql(owner, name, in_mysql)
          end
        end
      else
        if on_github.empty?
          # Project was deleted on Github. Mark it as deleted.
          set_deleted(owner, name)
        else
          update_mysql(owner, name, in_mysql)
        end
      end
    end
  end

  def go

    @ght ||= GHTorrent::Mirror.new(settings)

    unless ARGV[1].nil?
      process_project(ARGV[0], ARGV[1])
      exit(0)
    end

  end
end
