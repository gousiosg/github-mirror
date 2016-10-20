module GHTorrent
  module Commands
    module RepoUpdater

      include GHTorrent::Retriever
      include GHTorrent::Persister
      include GHTorrent::Logging

      def settings
        raise "Unimplemented"
      end

      def persister
        @persister ||= connect(:mongo, settings)
      end

      def db
        ght.db
      end

      def ght
        @ght ||= get_mirror_class.new(settings)
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
        info("Repo #{owner}/#{repo} marked as deleted")
      end

      def update_mysql(owner, repo, retrieved)

        parent = unless retrieved['parent'].nil?
                   ght.ensure_repo(retrieved['parent']['owner']['login'],
                                   retrieved['parent']['name'])
                 end

        fork_commit = ght.ensure_fork_point(owner, repo)

        unless parent.nil?
          sql = <<-SQL
            DELETE project_commits
            FROM project_commits, projects, users
            WHERE projects.owner_id = users.id
             AND project_commits.project_id = projects.id
             AND users.login = '#{owner}'
             AND projects.name = '#{repo}';
          SQL
          ndel = db[:project_commits].with_sql_delete(sql.gsub("\n",'').strip)
          debug("Deleted #{ndel} commit from project_commits for #{owner}/#{repo}")

          parent_owner = db[:users].where(:id => parent[:owner_id]).first[:login]
          ght.ensure_fork_commits(owner, repo, parent_owner, parent[:name])
        end

        db.from(:projects, :users).\
        where(:projects__owner_id => :users__id).\
        where(:users__login => owner).\
        where(:projects__name => repo).\
        update(:projects__url         => retrieved['url'],
               :projects__description => retrieved['description'],
               :projects__language    => retrieved['language'],
               :projects__created_at  => date(retrieved['created_at']),
               :projects__updated_at  => Time.now,
               :projects__forked_from => unless parent.nil? then parent[:id] end,
               :projects__forked_commit_id => unless fork_commit.nil? then fork_commit[:id] end)
        info("Repo #{owner}/#{repo} updated")

        ght.ensure_languages(owner, repo)
      end

      def get_project_mysql(owner, repo)
        db.from(:projects, :users).\
        where(:projects__owner_id => :users__id).\
        where(:users__login => owner).\
        where(:projects__name => repo).first
      end

      def update_mongo(owner, repo, new_repo)
        r = persister.del(:repos, {'owner.login' => owner, 'name' => repo})
        persister.store(:repos, new_repo)
        if r > 0
          debug("Persister entry for repo #{owner}/#{repo} updated (#{r} records removed)")
        else
          debug("Added persister entry for repo #{owner}/#{repo}")
        end
      end

      def process_project(owner, name)
        in_mongo = persister.find(:repos, {'owner.login' => owner, 'name' => name })
        on_github = api_request(ghurl ("repos/#{owner}/#{name}"))
        if on_github.nil?
          warn "Problem retrieving #{owner}/#{name} from GitHub"
          return
        end

        ght.transaction do

          unless in_mongo.empty? and on_github.empty?
            in_mysql = get_project_mysql(owner, name)
          end

          if in_mongo.empty?
            if on_github.empty?
              if in_mysql.nil?
                # Project does not exist anywhere
                warn "Repo #{owner}/#{name} does not exist anywhere"
              else
                # Project exists in MySQL but not on Github or Mongo
                # Mark it as deleted
                set_deleted(owner, name)
              end
            else
              if in_mysql.nil?
                # Project does not exist in MySQL or Mongo, but exists on Github
                update_mysql(owner, name, on_github)
              else
                # Project does not exist in Mongo, but exists on Github and MySQL
                update_mongo(owner, name, on_github)
                update_mysql(owner, name, on_github)
                return # This is to avoid calling update_mongo again at the end
              end
            end
          else
            if on_github.empty?
              if in_mysql.nil?
                # noop
              else
                # Project deleted on Github, but exists in Mongo and Mysql
                set_deleted(owner, name)
              end
            else
              if in_mysql.nil?
                #
                update_mysql(owner, name, on_github)
              else
                # Project exists in Mongo, Mysql and Gitub
                update_mysql(owner, name, on_github)
              end
            end
          end
        end

        # Refresh MongoDb with the latest info from GitHub
        unless on_github.empty?
          update_mongo(owner, name, on_github)
        end
      end
    end
  end
end
