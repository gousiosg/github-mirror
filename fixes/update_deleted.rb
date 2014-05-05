#!/usr/bin/env ruby

require 'ghtorrent'

class GHTFixDeleted < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def prepare_options(options)
    options.banner <<-BANNER
Updates the deleted field in the project table with current data

#{command_name} owner repo

    BANNER
  end

  def validate
    super
    Trollop::die "Either takes no arguments or two" if ARGV.size == 1
  end

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
    logger.info("Project #{owner}/#{repo} marked as deleted")
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
         :projects__forked_from => unless parent.nil? then parent[:id] end,
         :projects__ext_ref_id => retrieved[@ext_uniq])
    logger.debug("Project #{owner}/#{repo} updated")
  end

  def process_project(owner, name)
    @ght.transaction do

      existing = persister.find(:repos, {'owner.login' => owner, 'name' => name })
      on_github = api_request(ghurl ("repos/#{owner}/#{name}"))
      retrieved = retrieve_repo(owner, name)

      if existing.empty?
        if on_github.empty?
          # Project exists in MySQL but not on Github or Mongo
          # Mark it as deleted
          set_deleted(owner, name)
        else
          # Project does not exist in Mongo, but exists in MySQL and Github
          # The retrieval process already added it to Mongo, so update MySQL
          update_mysql(owner, name, retrieved)
        end
      else
        if on_github.empty?
          # Project was deleted on Github. Mark it as deleted.
          set_deleted(owner, name)
        else
          update_mysql(owner, name, retrieved)
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

    @ght.transaction do
      a = db.from(:projects, :users).\
             where(:projects__owner_id => :users__id).\
             select(:users__login, :projects__name).\
             all
      a.map { |x| [x[:login], x[:name]] }
    end.each do |p|
      owner = p[0]
      name = p[1]
      process_project(owner, name)
    end
  end
end

GHTFixDeleted.run