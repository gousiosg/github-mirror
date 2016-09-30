require 'sequel'

require 'ghtorrent/time'
require 'ghtorrent/logging'
require 'ghtorrent/settings'
require 'ghtorrent/retriever'
require 'ghtorrent/persister'
require 'ghtorrent/geolocator'

module GHTorrent
  class Mirror

    include GHTorrent::Logging
    include GHTorrent::Settings
    include GHTorrent::Retriever
    include GHTorrent::Persister
    include GHTorrent::Geolocator

    attr_reader :settings, :persister, :logger

    def initialize(settings)
      @settings = settings

      @retry_on_error = Array.new
      @retry_on_error <<  Mysql2::Error      if defined? Mysql2::Error
      @retry_on_error <<  SQLite3::Exception if defined? SQLite3::Exception
      @retry_on_error <<  PG::Error if defined? PG::Error
    end

    def dispose
      @db.disconnect unless @db.nil?
      @persister.close unless @persister.nil?
    end

    # Get a connection to the database
    def db
      return @db unless @db.nil?

      Sequel.single_threaded = true
      @db = Sequel.connect(config(:sql_url), :encoding => 'utf8')
      #@db.loggers << Logger.new(STDOUT)
      if @db.tables.empty?
        dir = File.join(File.dirname(__FILE__), 'migrations')
        puts "Database empty, running migrations from #{dir}"
        Sequel.extension :migration
        Sequel::Migrator.apply(@db, dir)
      end

      @db
    end

    def persister
      @persister ||= connect(config(:mirror_persister), @settings)
      @persister
    end

    ##
    # Make sure a commit exists
    #
    def ensure_commit(repo, sha, user, comments = true)
      ensure_repo(user, repo)
      c = retrieve_commit(repo, sha, user)

      if c.nil?
        warn "Commit #{user}/#{repo} -> #{sha} does not exist"
        return
      end

      stored = store_commit(c, repo, user)
      ensure_parents(c)
      if not c['commit']['comment_count'].nil? \
         and c['commit']['comment_count'] > 0
        ensure_commit_comments(user, repo, sha) if comments
      end
      ensure_repo_commit(user, repo, sha)
      stored
    end

    ##
    # Retrieve commits for a repository, starting from +sha+
    # ==Parameters:
    # [user]  The user to whom the repo belongs.
    # [repo]  The repo to look for commits into.
    # [sha]   The first commit to start retrieving from. If nil, then retrieval
    #         starts from what the project considers as master branch.
    # [return_retrieved] Should retrieved commits be returned? If not, memory is
    #                    saved while processing them.
    # [pages] Number of commits to retrieve. A negative number means retrieve all
    def ensure_commits(user, repo, sha = nil, return_retrieved = false, num_commits = -1)

      currepo = ensure_repo(user, repo)
      unless currepo[:forked_from].nil?
        r            = retrieve_repo(user, repo)
        parent_owner = r['parent']['owner']['login']
        parent_repo  = r['parent']['name']
        ensure_fork_commits(user, repo, parent_owner, parent_repo)
        return
      end

      num_retrieved = 0
      commits = ['foo'] # Dummy entry for simplifying the loop below
      commit_acc = []
      until commits.empty?
        commits = retrieve_commits(repo, sha, user, 1)

        # This means that we retrieved the last commit page again
        if commits.size == 1 and commits[0]['sha'] == sha
          commits = []
        end

        retrieved = commits.map do |c|
          sha = c['sha']
          save{ensure_commit(repo, c['sha'], user)}
        end

        # Store retrieved commits to return, if client requested so
        if return_retrieved
          commit_acc = commit_acc << retrieved
        end

        num_retrieved += retrieved.size
        if num_commits > 0 and num_retrieved >= num_commits
          break
        end

      end

      commit_acc.flatten.select{|x| !x.nil?}
    end

    ##
    # Get the parents for a specific commit. The commit must be first stored
    # in the database.
    def ensure_parents(commit)
      commits = db[:commits]
      parents = db[:commit_parents]
      commit['parents'].map do |p|
        save do
          url = p['url'].split(/\//)
          this = commits.first(:sha => commit['sha'])
          parent = commits.first(:sha => url[7])

          if parent.nil?
            c = retrieve_commit(url[5], url[7], url[4])
            if c.nil?
              warn "Could not retrieve commit_parent #{url[4]}/#{url[5]} -> #{url[7]} to #{this[:sha]}"
              next
            end
            parent = store_commit(c, url[5], url[4])
          end

          if parent.nil?
            warn "Could not find #{url[4]}/#{url[5]} -> #{url[7]}, parent to commit #{this[:sha]}"
            next
          end

          if parents.first(:commit_id => this[:id],
                           :parent_id => parent[:id]).nil?

            parents.insert(:commit_id => this[:id],
                           :parent_id => parent[:id])
            info "Added commit_parent #{parent[:sha]} to commit #{this[:sha]}"
          else
            debug "Parent #{parent[:sha]} for commit #{this[:sha]} exists"
          end
          parents.first(:commit_id => this[:id], :parent_id => parent[:id])
        end
      end.select{|x| !x.nil?}
    end

    ##
    # Make sure that a commit has been associated with the provided repo
    # ==Parameters:
    #  [user] The user that owns the repo this commit has been submitted to
    #  [repo] The repo receiving the commit
    #  [sha] The commit SHA
    def ensure_repo_commit(user, repo, sha)
      project = ensure_repo(user, repo)

      if project.nil?
        warn "Repo #{user}/#{repo} does not exist"
        return
      end

      commitid = db[:commits].first(:sha => sha)[:id]

      exists = db[:project_commits].first(:project_id => project[:id],
                                           :commit_id => commitid)
      if exists.nil?
        db[:project_commits].insert(
            :project_id => project[:id],
            :commit_id => commitid
        )
        info "Added commit_assoc of #{sha} with #{user}/#{repo}"
        db[:project_commits].first(:project_id => project[:id],
                                    :commit_id => commitid)
      else
        debug "Association of commit #{sha} with repo #{user}/#{repo} exists"
        exists
      end
    end

    ##
    # Add (or update) an entry for a commit author. This method uses information
    # in the JSON object returned by Github to add (or update) a user in the
    # metadata database with a full user entry (both Git and Github details).
    #
    # ==Parameters:
    # [githubuser]  A hash containing the user's Github login
    # [commituser]  A hash containing the Git commit's user name and email
    # == Returns:
    # The (added/modified) user entry as a Hash.
    def commit_user(githubuser, commituser)

      users = db[:users]

      name = commituser['name']
      email = commituser['email'] #if is_valid_email(commituser['email'])
      # Github user can be null when the commit email has not been associated
      # with any account in Github.
      login = githubuser['login'] unless githubuser.nil?

      # web-flow is a special user reserved for web-based commits:
      # https://api.github.com/users/web-flow
      # We do not follow the process below as this user's email
      # (noreply@github.com) clashes other existing users' emails.
      if login == 'web-flow'
        return ensure_user_byuname('web-flow')
      end

      return ensure_user("#{name}<#{email}>", false, false) if login.nil?

      dbuser = users.first(:login => login)
      byemail = users.first(:email => email)

      if dbuser.nil?
        # We do not have the user in the database yet
        added = ensure_user(login, false, false)

        # A commit user can be found by email but not
        # by the user name he used to commit. This probably means that the
        # user has probably changed his user name. Treat the user's by-email
        # description as valid.
        if added.nil? and not byemail.nil?
          warn "Found user #{byemail[:login]} with same email #{email} as non existing user #{login}. Assigning user #{login} to #{byemail[:login]}"
          return users.first(:login => byemail[:login])
        end

        # This means that the user's login has been associated with a
        # Github user by the time the commit was done (and hence Github was
        # able to associate the commit to an account), but afterwards the
        # user has deleted his account (before GHTorrent processed it).
        # On absense of something better to do, try to find the user by email
        # and return a "fake" user entry.
        if added.nil?
          warn "User account for user #{login} deleted from Github"
          return ensure_user("#{name}<#{email}>", false, false)
        end

        if byemail.nil?
          users.filter(:login => login).update(:name => name) if added[:name].nil?
          users.filter(:login => login).update(:email => email) if added[:email].nil?
        else
          # There is a previous entry for the user, currently identified by
          # email. This means that the user has updated his account and now
          # Github is able to associate his commits with his git credentials.
          # As the previous entry might have already associated records, just
          # delete the new one and update the existing with any extra data.
          users.filter(:login => login).delete
          users.filter(:email => email).update(
              :login => login,
              :company => added['company'],
              :location => added['location'],
              :created_at => added['created_at']
          )
        end
      else
        users.filter(:login => login).update(:name => name) if dbuser[:name].nil?
        users.filter(:login => login).update(:email => email) if dbuser[:email].nil?
      end
      users.first(:login => login)

    end

    ##
    # Ensure that a user exists, or fetch its latest state from Github
    # ==Parameters:
    #  [user] The full email address in RFC 822 format or a login name to lookup
    #         the user by
    #  [followers] A boolean value indicating whether to retrieve the user's
    #              followers
    #  [orgs] A boolean value indicating whether to retrieve the organizations
    #         the user participates into
    # ==Returns:
    # If the user can be retrieved, it is returned as a Hash. Otherwise,
    # the result is nil
    def ensure_user(user, followers = true, orgs = true)
      # Github only supports alpa-nums and dashes in its usernames.
      # All other sympbols are treated as emails.
      if not user.match(/^[\w\-]*$/)
        begin
          name, email = user.split("<")
          email = email.split(">")[0]
          name = name.strip unless name.nil?
          email = email.strip unless email.nil?
        rescue StandardError
          warn "Not a valid email address: #{user}"
          return
        end

        unless is_valid_email(email)
          warn "Extracted email(#{email}) not valid for user #{user}"
        end
        u = ensure_user_byemail(email, name)
      else
        u = ensure_user_byuname(user)
        ensure_user_followers(user) if followers
        ensure_orgs(user) if orgs
      end
      return u
    end

    ##
    # Ensure that a user exists, or fetch its latest state from Github
    # ==Parameters:
    #  user::
    #     The login name to lookup the user by
    #
    # == Returns:
    # If the user can be retrieved, it is returned as a Hash. Otherwise,
    # the result is nil
    def ensure_user_byuname(user)
      users = db[:users]
      usr = users.first(:login => user)

      if usr.nil?
        u = retrieve_user_byusername(user)

        if u.nil?
          warn "User #{user} does not exist"
          return
        end

        email = unless u['email'].nil?
                  if u['email'].strip == '' then
                    nil
                  else
                    u['email'].strip
                  end
                end

        geo = geolocate(u['location'])

        users.insert(:login => u['login'],
                     :name => u['name'],
                     :company => u['company'],
                     :email => email,
                     :fake => false,
                     :deleted => false,
                     :type => user_type(u['type']),
                     :long => geo[:long],
                     :lat => geo[:lat],
                     :country_code => geo[:country_code],
                     :state => geo[:state],
                     :city => geo[:city],
                     :created_at => date(u['created_at']))

        info "Added user #{user}"

        if user_type(u['type']) == 'ORG'
          info "User #{user} is an organization. Retrieving members"
          ensure_org(u['login'], true)
        end

        users.first(:login => user)
      else
        debug "User #{user} exists"
        usr
      end
    end

    ##
    # Get all followers for a user. Since we do not know when the actual
    # follow event took place, we set the created_at field to the timestamp
    # of the method call.
    #
    # ==Parameters:
    # [user]  The user login to find followers by
    def ensure_user_followers(followed)
      curuser = ensure_user(followed, false, false)
      followers = db.from(:followers, :users).\
          where(:followers__follower_id => :users__id).
          where(:followers__user_id => curuser[:id]).select(:login).all

      retrieve_user_followers(followed).reduce([]) do |acc, x|
        if followers.find {|y| y[:login] == x['login']}.nil?
          acc << x
        else
          acc
        end
      end.map { |x| save{ensure_user_follower(followed, x['login']) }}.select{|x| !x.nil?}
    end

    ##
    # Make sure that a user follows another one
    def ensure_user_follower(followed, follower, date_added = nil)
      follower_user = ensure_user(follower, false, false)
      followed_user = ensure_user(followed, false, false)

      if followed_user.nil? or follower_user.nil?
        warn "Could not find follower #{follower} or user #{followed}"
        return
      end

      followers = db[:followers]
      follower_id = follower_user[:id]
      followed_id = followed_user[:id]

      follower_exists = followers.first(:user_id => followed_id,
                                        :follower_id => follower_id)
      if follower_exists.nil?
        added = if date_added.nil?
                  max(follower_user[:created_at], followed_user[:created_at])
                else
                  date_added
                end
        retrieved = retrieve_user_follower(followed, follower)

        if retrieved.nil?
          warn "Could not retrieve follower #{follower} for #{followed}"
          return
        end

        followers.insert(:user_id => followed_id,
                         :follower_id => follower_id,
                         :created_at => added)
        info "Added follower #{follower} to #{followed}"
      else
        debug "Follower #{follower} for user #{followed} exists"
      end

      unless date_added.nil?
        followers.filter(:user_id => followed_id, :follower_id => follower_id)
                 .update(:created_at => date(date_added))
        info "Updated follower #{followed} -> #{follower}, created_at -> #{date(date_added)}"
      end

      followers.first(:user_id => followed_id, :follower_id => follower_id)
    end

    def ensure_user_following(user)
      curuser = ensure_user(user, false, false)
      following = db.from(:followers, :users).\
          where(:followers__follower_id => curuser[:id]).\
          where(:followers__user_id => :users__id).select(:login).all

      retrieve_user_following(user).reduce([]) do |acc, x|
         if following.find {|y| y[:login] == x['follows']}.nil?
           acc << x
         else
           acc
         end
       end.map { |x| save{ensure_user_follower(x['follows'], user) }}.select{|x| !x.nil?}
    end

    ##
    # Try to retrieve a user by email. Search the DB first, fall back to
    # Github search API if unsuccessful.
    #
    # ==Parameters:
    # [email]  The email to lookup the user by
    # [name]  The user's name
    # == Returns:
    # If the user can be retrieved, it is returned as a Hash. Otherwise,
    # the result is nil
    def ensure_user_byemail(email, name)
      users = db[:users]
      usr = users.first(:email => email)

      if usr.nil?

        u = retrieve_user_byemail(email, name)

        if u.nil? or u['login'].nil?
          warn "Could not retrieve user #{email} through search API query"
          login = (0...8).map { 65.+(rand(25)).chr }.join
          users.insert(:email => email,
                       :name => name,
                       :login => login,
                       :fake => true,
                       :deleted => false,
                       :created_at => Time.now)
          info "Added user fake #{login} -> #{email}"
          users.first(:login => login)
        else
          in_db = users.first(:login => u['login'])
          geo = geolocate(u['location'])
          if in_db.nil?
            users.insert(:login => u['login'],
                         :name => u['name'],
                         :company => u['company'],
                         :email => u['email'],
                         :long => geo[:long],
                         :lat => geo[:lat],
                         :country_code => geo[:country_code],
                         :state => geo[:state],
                         :city => geo[:city],
                         :fake => false,
                         :deleted => false,
                         :created_at => date(u['created_at']))
            info "Added user #{u['login']} (#{email}) through search API query"
          else
            in_db.update(:name => u['name'],
                         :company => u['company'],
                         :email => u['email'],
                         :long => geo[:long],
                         :lat => geo[:lat],
                         :country_code => geo[:country_code],
                         :state => geo[:state],
                         :city => geo[:city],
                         :fake => false,
                         :deleted => false,
                         :created_at => date(u['created_at']))
            debug "User #{u['login']} with email #{email} exists"
          end
          users.first(:login => u['login'])
        end
      else
        debug "User with email #{email} exists"
        usr
      end
    end

    ##
    # Ensure that a repo exists, or fetch its latest state from Github
    #
    # ==Parameters:
    # [user]  The email or login name to which this repo belongs
    # [repo]  The repo name
    #
    # == Returns:
    #  If the repo can be retrieved, it is returned as a Hash. Otherwise,
    #  the result is nil
    def ensure_repo(user, repo, recursive = false)

      repos = db[:projects]
      curuser = ensure_user(user, false, false)

      if curuser.nil?
        warn "Could not find user #{user}"
        return
      end

      currepo = repos.first(:owner_id => curuser[:id], :name => repo)

      unless currepo.nil?
        debug "Repo #{user}/#{repo} exists"
        return currepo
      end

      r = retrieve_repo(user, repo)

      if r.nil?
        warn "Could not retrieve repo #{user}/#{repo}"
        return
      end

      repos.insert(:url => r['url'],
                   :owner_id => curuser[:id],
                   :name => r['name'],
                   :description => unless r['description'].nil? then r['description'][0..254] else nil end,
                   :language => r['language'],
                   :created_at => date(r['created_at']),
                   :updated_at => Time.at(86400))

      unless r['parent'].nil?
        parent_owner = r['parent']['owner']['login']
        parent_repo = r['parent']['name']

        parent = ensure_repo(parent_owner, parent_repo)

        if parent.nil?
          warn "Could not find repo #{parent_owner}/#{parent_repo}, parent of: #{user}/#{repo}"
          repos.filter(:owner_id => curuser[:id], :name => repo).update(:forked_from => -1)
        else
          repos.filter(:owner_id => curuser[:id], :name => repo).update(:forked_from => parent[:id])
          info "Repo #{user}/#{repo} is a fork of #{parent_owner}/#{parent_repo}"

          forked_commit = ensure_fork_point(user, repo)
        end
      end

      info "Added repo #{user}/#{repo}"

      ensure_repo_recursive(user, repo) if recursive

      repos.first(:owner_id => curuser[:id], :name => repo)
    end

    def ensure_repo_recursive(owner, repo)

      functions = %w(ensure_commits ensure_labels ensure_pull_requests
       ensure_issues ensure_watchers ensure_forks ensure_languages)

      functions.each do |x|
        send(x, owner, repo)
      end

    end

    # Get details about the languages used in the repository
    def ensure_languages(owner, repo)
      currepo = ensure_repo(owner, repo)
      langs = retrieve_languages(owner, repo)

      if langs.nil? or langs.empty?
        warn "Could not find languages for repo #{owner}/#{repo}"
        return
      end

      ts = Time.now
      langs.keys.each do |lang|
        db[:project_languages].insert(
          :project_id => currepo[:id],
          :language   => lang.downcase,
          :bytes      => langs[lang],
          :created_at => ts
        )
        info "Added project_language #{owner}/#{repo} -> #{lang} (#{langs[lang]} bytes)"
      end
      db[:project_languages].where(:project_id => currepo[:id]).where(:created_at => ts).all
    end

    # Fast path to project forking. Retrieve all commits page by page
    # until we reach a commit that has been registered with the parent
    # repository. Then, copy all remaining parent commits to this repo.
    def ensure_fork_commits(owner, repo, parent_owner, parent_repo)

      currepo = ensure_repo(owner, repo)

      if currepo.nil?
        warn "Could not find repo #{owner}/#{repo}"
        return
      end

      parent = ensure_repo(parent_owner, parent_repo)

      if parent.nil?
        warn "Could not find repo #{parent_owner}/#{parent_repo}, parent of #{owner}/#{repo}"
        return
      end

      strategy = case
                   when config(:fork_commits).match(/all/i)
                     :all
                   when config(:fork_commits).match(/fork_point/i)
                     :fork_point
                   when config(:fork_commits).match(/none/i)
                     :none
                   else
                     :fork_point
                 end

      fork_commit = ensure_fork_point(owner, repo)

      if fork_commit.nil? or fork_commit.empty?
        warn "Cannot find fork commit for repo #{owner}/#{repo}. Retrieving all commits."
        return ensure_commits(owner, repo)
      end

      debug "Retrieving commits for fork #{owner}/#{repo}: strategy is #{strategy}"
      return if strategy == :none

      if strategy == :fork_point
        # Retrieve commits up to fork point (fork_commit strategy)
        info "Retrieving commits for #{owner}/#{repo} until fork commit #{fork_commit[:sha]}"
        master_branch = retrieve_default_branch(parent_owner, parent_repo)

        sha   = master_branch
        found = false
        while not found
          commits = retrieve_commits(repo, sha, owner, 1)

          # This means we retrieved the last page again
          if commits.size == 1 and commits[0]['sha'] == sha
            break
          end

          for c in commits
            ensure_commit(repo, c['sha'], owner)
            sha = c['sha']
            if c['sha'] == fork_commit[:sha]
              found = true
              break
            end
          end
        end
      end

      if strategy == :all

        shared_commit = db[:commits].first(:sha => fork_commit)
        copied        = 0
        to_copy = db.from(:project_commits, :commits).\
                  where(:project_commits__commit_id => :commits__id).\
                  where(:project_commits__project_id => parent[:id]).\
                  where('commits.created_at < ?', shared_commit[:created_at]).\
                  select(:commits__id)

        to_copy.each do |c|
          copied += 1
          begin
            db[:project_commits].insert(
                :project_id => currepo[:id],
                :commit_id  => c[:id]
            )
            debug "Copied commit #{c[:sha]} #{parent_owner}/#{parent_repo} -> #{owner}/#{repo} (#{copied} total)"
          rescue StandardError => e
            warn "Could not copy commit #{c[:sha]} #{parent_owner}/#{parent_repo} -> #{owner}/#{repo} : #{e.message}"
          end
        end
        info "Finished copying commits from #{parent_owner}/#{parent_repo} -> #{owner}/#{repo}: #{copied} total"
      end

    end

    # Retrieve and return the commit at which the provided fork was forked at
    def ensure_fork_point(owner, repo)

      fork = ensure_repo(owner, repo, false)

      if fork[:forked_from].nil?
        warn "Repo #{owner}/#{repo} is not a fork"
        return nil
      end

      # Return commit if already specified
      unless fork[:forked_commit_id].nil?
        commit = db[:commits].where(:id => fork[:forked_commit_id]).first
        return commit unless commit.nil?
      end

      parent = db.from(:projects, :users).\
                where(:projects__owner_id => :users__id).\
                where(:projects__id => fork[:forked_from]).\
                select(:users__login, :projects__name).first

      if parent.nil?
        warn "Unknown parent for repo #{owner}/#{repo}"
        return nil
      end

      default_branch = retrieve_default_branch(parent[:login], parent[:name])

      # Retrieve diff between parent and fork master branch
      diff = retrieve_master_branch_diff(owner, repo, default_branch, parent[:login], parent[:name], default_branch)
      if diff.empty?
        # This means that the are no common ancestors between the repos
        # This can apparently happen when the parent repo was renamed or force-pushed
        # example: https://github.com/openzipkin/zipkin/compare/master...aa1wi:master
        warn "No common ancestor between #{parent[:login]}/#{parent[:name]} and #{owner}/#{repo}"
        return nil
      else
        debug "Fork #{owner}/#{repo} is #{diff['ahead_by']} commits ahead and #{diff['behind_by']} commits behind #{parent[:login]}/#{parent[:name]}"
      end

      if diff['ahead_by'].to_i > 0
        # This means that the fork has diverged, and we need to search through the fork
        # commit graph for the earliest commit that is shared with the parent. GitHub's
        # diff contains a list of divergent commits. We are sorting those by date
        # and select the earliest one. We do date sort instead of graph walking as this
        # would be prohibetively slow if the commits for the parent did not exist.
        earliest_diverging = diff['commits'].sort_by{|x| x['commit']['author']['date']}.first

        # Make sure that all likely fork points exist for the parent project
        # and select the latest of them.
        # https://github.com/gousiosg/github-mirror/compare/master...pombredanne:master
        likely_fork_point = earliest_diverging['parents'].\
            map{ |x| ensure_commit(parent[:name], x['sha'], parent[:login])}.\
            select{|x| !x.nil?}.\
            sort_by { |x| x[:created_at]}.\
            last

        forked_sha  = likely_fork_point[:sha]
      else
        # This means that the fork has not diverged.
        forked_sha = diff['merge_base_commit']['sha']
      end

      forked_commit = ensure_commit(repo, forked_sha, owner);

      debug "Fork commit for #{owner}/#{repo} is #{forked_sha}"

      unless forked_commit.nil?
        db[:projects].filter(:id => fork[:id]).update(:forked_commit_id => forked_commit[:id])
        info "Repo #{owner}/#{repo} was forked at #{parent[:login]}/#{parent[:name]}:#{forked_sha}"
      end

      db[:commits].where(:sha => forked_sha).first
    end

    ##
    # Make sure that a project has all the registered members defined
    def ensure_project_members(user, repo, refresh = false)
      currepo = ensure_repo(user, repo)
      time = currepo[:created_at]

      project_members = db.from(:project_members, :users).\
          where(:project_members__user_id => :users__id).\
          where(:project_members__repo_id => currepo[:id]).select(:login).all

      retrieve_repo_collaborators(user, repo).reduce([]) do |acc, x|
        if project_members.find {|y| y[:login] == x['login']}.nil?
          acc << x
        else
          acc
        end
      end.map { |x| save{ensure_project_member(user, repo, x['login'], time) }}.select{|x| !x.nil?}
    end

    ##
    # Make sure that a project member exists in a project
    def ensure_project_member(owner, repo, new_member, date_added)
      pr_members = db[:project_members]
      project = ensure_repo(owner, repo)
      new_user = ensure_user(new_member, false, false)

      if project.nil? or new_user.nil?
        warn "Could not find repo #{owner}/#{repo} or member #{new_member}"
        return
      end

      memb_exist = pr_members.first(:user_id => new_user[:id],
                                    :repo_id => project[:id])

      if memb_exist.nil?
        added = if date_added.nil?
                  max(project[:created_at], new_user[:created_at])
                else
                  date_added
                end
        retrieved = retrieve_repo_collaborator(owner, repo, new_member)

        if retrieved.nil?
          warn "Could not retrieve member #{new_member} of #{owner}/#{repo}"
          return
        end

        pr_members.insert(
            :user_id => new_user[:id],
            :repo_id => project[:id],
            :created_at => date(added)
        )
        info "Added project_member #{repo} -> #{new_member}"
      else
        debug "Project member #{repo} -> #{new_member} exists"
      end

      unless date_added.nil?
        pr_members.filter(:user_id => new_user[:id],
                          :repo_id => project[:id])\
                    .update(:created_at => date(date_added))
        info "Updated project member #{repo} -> #{new_member}, created_at -> #{date(date_added)}"
      end
    end

    ##
    # Make sure that the organizations the user participates into exist
    #
    # ==Parameters:
    # [user]  The login name of the user to check the organizations for
    #
    def ensure_orgs(user)
      retrieve_orgs(user).map{|o| save{ensure_participation(user, o['login'])}}.select{|x| !x.nil?}
    end

    ##
    # Make sure that a user participates to the provided organization
    #
    # ==Parameters:
    # [user] The login name of the user to check the organizations for
    # [org]  The login name of the organization to check whether the user
    #        belongs in
    #
    def ensure_participation(user, organization, members = true)
      org = ensure_org(organization, members)

      if org.nil?
        warn "Could not find organization #{organization}"
        return
      end

      usr = ensure_user(user, false, false)

      org_members = db[:organization_members]
      participates = org_members.first(:user_id => usr[:id], :org_id => org[:id])

      if participates.nil?
        org_members.insert(:user_id => usr[:id],
                           :org_id => org[:id])
        info "Added participation #{organization} -> #{user}"
        org_members.first(:user_id => usr[:id], :org_id => org[:id])
      else
        debug "Participation #{organization} -> #{user} exists"
        participates
      end

    end

    ##
    # Make sure that an organization exists
    #
    # ==Parameters:
    # [organization]  The login name of the organization
    #
    def ensure_org(organization, members = true)
      org = db[:users].first(:login => organization, :type => 'org')

      if org.nil?
        org = ensure_user(organization, false, false)

        # Not an organization, don't go ahead
        if org[:type] != 'ORG'
          warn "User #{organization} is not an organization"
          return nil
        end
      end
      if members
        retrieve_org_members(organization).map do |x|
          ensure_participation(ensure_user(x['login'], false, false)[:login],
                               organization, false)
        end
      end
      org
    end

    ##
    # Get all comments for a commit
    #
    # ==Parameters:
    # [user]  The login name of the organization
    # [user]  The repository containing the commit whose comments will be retrieved
    # [sha]  The commit sha to retrieve comments for
    def ensure_commit_comments(user, repo, sha)
      commit_id = db[:commits].first(:sha => sha)[:id]
      stored_comments = db[:commit_comments].filter(:commit_id => commit_id)
      commit_comments = retrieve_commit_comments(user, repo, sha)

      not_saved = commit_comments.reduce([]) do |acc, x|
        if stored_comments.find{|y| y[:comment_id] == x['id']}.nil?
          acc << x
        else
          acc
        end
      end

      not_saved.map{|x| save{ensure_commit_comment(user, repo, sha, x['id'])}}.select{|x| !x.nil?}
    end


    def ensure_commit_comment(owner, repo, sha, comment_id)
      stored_comment = db[:commit_comments].first(:comment_id => comment_id)

      if stored_comment.nil?
        retrieved = retrieve_commit_comment(owner, repo, sha, comment_id)

        if retrieved.nil?
          warn "Could not retrieve commit_comment #{sha}->#{comment_id}"
          return
        end

        commit = ensure_commit(repo, sha, owner, false)
        user = ensure_user(retrieved['user']['login'], false, false)
        db[:commit_comments].insert(
            :commit_id => commit[:id],
            :user_id => user[:id],
            :body => retrieved['body'][0..255],
            :line => retrieved['line'],
            :position => retrieved['position'],
            :comment_id => retrieved['id'],
            :created_at => date(retrieved['created_at'])
        )
        info "Added commit_comment #{owner}/#{repo} -> #{sha}/#{retrieved['id']} by user #{user[:login]}"
      else
        debug "Commit comment #{sha} -> #{comment_id} exists"
      end
      db[:commit_comments].first(:comment_id => comment_id)
    end

    ##
    # Make sure that all watchers exist for a repository
    def ensure_watchers(owner, repo, refresh = false)
      currepo = ensure_repo(owner, repo)

      if currepo.nil?
        warn "Could not find repo #{owner}/#{repo} for retrieving watchers"
        return
      end

      watchers = db.from(:watchers, :users).\
          where(:watchers__user_id => :users__id).\
          where(:watchers__repo_id => currepo[:id]).select(:login).all

      retrieve_watchers(owner, repo).reduce([]) do |acc, x|
        if watchers.find { |y|
          y[:login] == x['login']
        }.nil?
          acc << x
        else
          acc
        end
      end.map { |x| save{ensure_watcher(owner, repo, x['login'], nil) }}.select{|x| !x.nil?}
    end

    ##
    # Make sure that a watcher/stargazer exists for a repository
    def ensure_watcher(owner, repo, watcher, date_added = nil)
      project = ensure_repo(owner, repo)
      new_watcher = ensure_user(watcher, false, false)

      if new_watcher.nil? or project.nil?
        warn "Could not find watcher #{watcher} or repo #{owner}/#{repo}"
        return
      end

      watchers = db[:watchers]
      watcher_exist = watchers.first(:user_id => new_watcher[:id],
                                     :repo_id => project[:id])

      retrieved = retrieve_watcher(owner, repo, watcher)

      created_at = case
                     when (not date_added.nil?)
                       date_added
                     when (not retrieved.nil? and not retrieved['created_at'].nil?)
                       retrieved['created_at']
                     else
                       max(project[:created_at], new_watcher[:created_at])
                   end

      if watcher_exist.nil?

        if retrieved.nil?
          warn "Could not retrieve watcher #{watcher} of repo #{owner}/#{repo}"
          return
        end

        watchers.insert(
            :user_id => new_watcher[:id],
            :repo_id => project[:id],
            :created_at => date(created_at)
        )
        info "Added watcher #{owner}/#{repo} -> #{watcher}"
      else
        debug "Watcher #{owner}/#{repo} -> #{watcher} exists"
      end

      w = watchers.first(:user_id => new_watcher[:id],
                     :repo_id => project[:id])

      if w[:created_at]  < Time.parse(created_at)
        watchers.filter(:user_id => new_watcher[:id],
                        :repo_id => project[:id])\
                .update(:created_at => date(created_at))
        info "Updated watcher #{owner}/#{repo} -> #{watcher}, created_at -> #{date_added}"
      end

      w
    end

    ##
    # Process all pull requests
    def ensure_pull_requests(owner, repo, refresh = false)
      currepo = ensure_repo(owner, repo)
      if currepo.nil?
        warn "Could not find repo #{owner}/#{repo} for retrieving pull requests"
        return
      end

      raw_pull_reqs = if refresh
                        retrieve_pull_requests(owner, repo, refresh = true)
                      else
                        pull_reqs = db[:pull_requests].filter(:base_repo_id => currepo[:id]).all
                        retrieve_pull_requests(owner, repo).reduce([]) do |acc, x|
                          if pull_reqs.find { |y| y[:pullreq_id] == x['number'] }.nil?
                            acc << x
                          else
                            acc
                          end
                        end
                      end

      raw_pull_reqs.map { |x| save { ensure_pull_request(owner, repo, x['number']) } }.select { |x| !x.nil? }
    end

    # Adds a pull request history event
    def ensure_pull_request_history(id, ts, act, actor)
      user = unless actor.nil?
               ensure_user(actor, false, false)
             end
      pull_req_history = db[:pull_request_history]

      entry =  if ['opened', 'merged'].include? act
                  pull_req_history.first(:pull_request_id => id,
                                         :action => act)
               else
                 pull_req_history.first(:pull_request_id => id,
                                        :created_at => (ts - 3)..(ts + 3),
                                        :action => act)
               end

      if entry.nil?
        pull_req_history.insert(:pull_request_id => id,
                                :created_at => ts,
                                :action => act,
                                :actor_id => unless user.nil? then user[:id] end)
        info "Added pullreq_event (#{id}) -> (#{act}) by (#{actor}) timestamp #{ts}"
      else
        debug "Pull request (#{id}) event (#{act}) by (#{actor}) timestamp #{ts} exists"
        if entry[:actor_id].nil? and not user.nil?
          pull_req_history.where(:pull_request_id => id,
                               :created_at => (ts - 3)..(ts + 3),
                               :action => act)\
                          .update(:actor_id => user[:id])
          info "Updated pull request (#{id}) event (#{act}) timestamp #{ts}, actor -> #{user[:login]}"
        end
      end
    end

    # Checks whether a pull request concerns two branches of the same
    # repository
    def pr_is_intra_branch(req)
      return false unless pr_has_head_repo(req)

      if req['head']['repo']['owner']['login'] ==
          req['base']['repo']['owner']['login'] and
          req['head']['repo']['full_name'] == req['base']['repo']['full_name']
        true
      else
        false
      end
    end

    # Checks if the pull request has a head repo specified
    def pr_has_head_repo(req)
      not req['head']['repo'].nil?
    end

    # Produces a log message
    def pr_log_msg(req)
      head = if pr_has_head_repo(req)
               req['head']['repo']['full_name']
             else
               '(head deleted)'
             end

      <<-eos.gsub(/\s+/, ' ').strip
            pull_req #{req['number']}
      #{head} -> #{req['base']['repo']['full_name']}
      eos
    end

    ##
    # Process a pull request
    def ensure_pull_request(owner, repo, pullreq_id,
                            comments = true, commits = true, history = true,
                            state = nil, actor = nil, created_at = nil)
      pulls_reqs = db[:pull_requests]

      project = ensure_repo(owner, repo)

      if project.nil?
        warn "Could not find repo #{owner}/#{repo} for retrieving pull request #{pullreq_id}"
        return
      end

      retrieved = retrieve_pull_request(owner, repo, pullreq_id)

      if retrieved.nil?
        warn "Could not retrieve pull_req #{owner}/#{repo} -> #{pullreq_id}"
        return
      end

      base_repo = ensure_repo(retrieved['base']['repo']['owner']['login'],
                              retrieved['base']['repo']['name'])

      base_commit = ensure_commit(retrieved['base']['repo']['name'],
                                  retrieved['base']['sha'],
                                  retrieved['base']['repo']['owner']['login'])

      if pr_is_intra_branch(retrieved)
        head_repo = base_repo
        head_commit = ensure_commit(retrieved['base']['repo']['name'],
                                    retrieved['head']['sha'],
                                    retrieved['base']['repo']['owner']['login'])
        debug pr_log_msg(retrieved) + ' is intra-branch'
      else
        head_repo = if pr_has_head_repo(retrieved)
                      ensure_repo(retrieved['head']['repo']['owner']['login'],
                                  retrieved['head']['repo']['name'])
                    end

        head_commit = if not head_repo.nil?
                        ensure_commit(retrieved['head']['repo']['name'],
                                      retrieved['head']['sha'],
                                      retrieved['head']['repo']['owner']['login'])
                      end
      end

      pull_req_user = ensure_user(retrieved['user']['login'], false, false)

      merged = if retrieved['merged_at'].nil? then false else true end
      closed = if retrieved['closed_at'].nil? then false else true end

      pull_req = pulls_reqs.first(:base_repo_id => project[:id],
                                  :pullreq_id => pullreq_id)
      if pull_req.nil?
        pulls_reqs.insert(
            :head_repo_id => if not head_repo.nil? then head_repo[:id] end,
            :base_repo_id => base_repo[:id],
            :head_commit_id => if not head_commit.nil? then head_commit[:id] end,
            :base_commit_id => base_commit[:id],
            :pullreq_id => pullreq_id,
            :intra_branch => pr_is_intra_branch(retrieved)
        )
        info 'Added ' + pr_log_msg(retrieved)
      else
        debug pr_log_msg(retrieved) + ' exists'
      end

      pull_req = pulls_reqs.first(:base_repo_id => project[:id],
                                  :pullreq_id => pullreq_id)

      # Add a fake (or not so fake) issue in the issues table to serve
      # as root for retrieving discussion comments for this pull request
      issues = db[:issues]
      issue = issues.first(:pull_request_id => pull_req[:id])

      if issue.nil?
        issues.insert(:repo_id => base_repo[:id],
                      :assignee_id => nil,
                      :reporter_id => nil,
                      :issue_id => pullreq_id,
                      :pull_request => true,
                      :pull_request_id => pull_req[:id],
                      :created_at => date(retrieved['created_at']))
        debug 'Added accompanying_issue for ' + pr_log_msg(retrieved)
      else
        debug 'Accompanying issue for ' + pr_log_msg(retrieved) + ' exists'
      end

      if history
        # Actions on pull requests
        opener = pull_req_user[:login]
        ensure_pull_request_history(pull_req[:id], date(retrieved['created_at']),
                                    'opened', opener)

        merger = if retrieved['merged_by'].nil? then actor else retrieved['merged_by']['login'] end
        ensure_pull_request_history(pull_req[:id], date(retrieved['merged_at']),
                                    'merged', merger) if (merged && state != 'merged')

        closer = if merged then merger else actor end
        ensure_pull_request_history(pull_req[:id], date(retrieved['closed_at']),
                                    'closed', closer) if (closed && state != 'closed')
        ensure_pull_request_history(pull_req[:id], date(created_at), state, actor) unless state.nil?
      end
      ensure_pull_request_commits(owner, repo, pullreq_id, pull_req) if commits
      ensure_pullreq_comments(owner, repo, pullreq_id, pull_req) if comments
      ensure_issue_comments(owner, repo, pullreq_id, pull_req[:id]) if comments

      pull_req
    end

    def ensure_pullreq_comments(owner, repo, pullreq_id, pr_obj = nil)
      pull_req = pr_obj
      pull_req = ensure_pull_request(owner, repo, pullreq_id, false, false, false) if pr_obj.nil?

      if pull_req.nil?
        warn "Could not find pull_req #{owner}/#{repo} -> #{pullreq_id}"
        return
      end

      retrieve_pull_req_comments(owner, repo, pullreq_id).reduce([]) do |acc, x|

        if db[:pull_request_comments].first(:pull_request_id => pull_req[:id],
                                             :comment_id => x['id']).nil?
          acc << x
        else
          acc
        end
      end.map { |x|
        save{ensure_pullreq_comment(owner, repo, pullreq_id, x['id'], pr_obj)}
      }.select{|x| !x.nil?}
    end

    def ensure_pullreq_comment(owner, repo, pullreq_id, comment_id, pr_obj = nil)
      # Commit retrieval is set to false to ensure that no duplicate work
      # is done on retrieving a pull request. This has the side effect that
      # commits might not be retrieved if a pullreqcomment event gets processed
      # before the pullreq event, until the pullreq event has been processed
      pull_req = pr_obj
      pull_req = ensure_pull_request(owner, repo, pullreq_id, false, false, false) if pr_obj.nil?

      if pull_req.nil?
        warn "Could not find pull req #{owner}/#{repo} -> #{pullreq_id} for retrieving comment #{comment_id}"
        return
      end

      exists = db[:pull_request_comments].first(:pull_request_id => pull_req[:id],
                                                 :comment_id => comment_id)

      if exists.nil?
        retrieved = retrieve_pull_req_comment(owner, repo, pullreq_id, comment_id)

        if retrieved.nil?
          warn "Could not retrieve pullreq_comment #{comment_id} for #{owner}/#{repo} -> #{pullreq_id}"
          return
        end

        commenter = ensure_user(retrieved['user']['login'], false, false)

        if commenter.nil?
          warn "Could not find commenter #{retrieved['user']['login']}" +
               "for pullreq comment #{owner}/#{repo} -> #{pullreq_id}(#{comment_id}) "
        end

        commit = ensure_commit(repo, retrieved['original_commit_id'],owner)

        db[:pull_request_comments].insert(
            :pull_request_id => pull_req[:id],
            :user_id => commenter[:id],
            :comment_id => comment_id,
            :position => retrieved['original_position'],
            :body => retrieved['body'][0..254],
            :commit_id => (commit[:id] unless commit.nil?),
            :created_at => date(retrieved['created_at'])
        )
        info "Added pullreq_comment #{comment_id} for #{owner}/#{repo} -> #{pullreq_id}"
        db[:pull_request_comments].first(:pull_request_id => pull_req[:id],
                                          :comment_id => comment_id)
      else
        debug "Comment #{comment_id} for pullreq #{owner}/#{repo} -> #{pullreq_id} exists"
        exists
      end
    end

    def ensure_pull_request_commits(owner, repo, pullreq_id, pr_obj)
      pullreq = pr_obj
      pullreq = ensure_pull_request(owner, repo, pullreq_id, false, false, false) if pr_obj.nil?

      if pullreq.nil?
        warn "Could not find pull request #{owner}/#{repo} -> #{pullreq_id} for retrieving commits"
        return
      end

      retrieve_pull_req_commits(owner, repo, pullreq_id).reduce([]) { |acc, c|
        next if c.nil?
        head_repo_owner = c['url'].split(/\//)[4]
        head_repo_name = c['url'].split(/\//)[5]
        x = ensure_commit(head_repo_name, c['sha'], head_repo_owner)
        acc << x unless x.nil?
        acc
      }.map do |c|
        save do
          exists = db[:pull_request_commits].first(:pull_request_id => pullreq[:id],
                                                    :commit_id => c[:id])
          if exists.nil?
            db[:pull_request_commits].insert(:pull_request_id => pullreq[:id],
                                              :commit_id => c[:id])

            info "Added pullreq_commit #{c[:sha]} to #{owner}/#{repo} -> #{pullreq_id}"
          else
            debug "Commit #{c[:sha]} in pullreq #{owner}/#{repo} -> #{pullreq_id} exists"
            exists
          end
        end
      end.select{|x| !x.nil?}
    end

    ##
    # Get all forks for a project.
    #
    # ==Parameters:
    # [owner]  The user to which the project belongs
    # [repo]  The repository/project to find forks for
    def ensure_forks(owner, repo)
      currepo = ensure_repo(owner, repo)

      if currepo.nil?
        warn "Could not find repo #{owner}/#{repo} for retrieving forks"
        return
      end

      existing_forks = db.from(:projects, :users).\
          where(:users__id => :projects__owner_id). \
          where(:projects__forked_from => currepo[:id]).select(:projects__name, :login).all

      retrieve_forks(owner, repo).reduce([]) do |acc, x|
        if existing_forks.find do |y|
          forked_repo_owner = x['full_name'].split(/\//)[0]
          forked_repo_name = x['full_name'].split(/\//)[1]
          y[:login] == forked_repo_owner && y[:name] == forked_repo_name
        end.nil?
          acc << x
        else
          acc
        end
      end.map { |x| save{ensure_fork(owner, repo, x['id']) }}.select{|x| !x.nil?}
    end

    ##
    # Make sure that a fork is retrieved for a project
    def ensure_fork(owner, repo, fork_id)
      fork = retrieve_fork(owner, repo, fork_id)

      if fork.nil?
        warn "Could not retrieve fork #{owner}/#{repo} -> #{fork_id}"
        return
      end

      fork_name = if fork['full_name'].nil? then fork['url'].split(/\//)[4..5].join('/') else fork['full_name'] end
      fork_owner = fork_name.split(/\//)[0]
      fork_name = fork_name.split(/\//)[1]

      r = ensure_repo(fork_owner, fork_name, true)

      if r.nil?
        warn "Could not add #{fork_owner}/#{fork_name} as fork of #{owner}/#{repo}"
      else
        info "Added fork #{fork_owner}/#{fork_name} of #{owner}/#{repo}"
      end
      r
    end

    ##
    # Make sure all issues exist for a project
    def ensure_issues(owner, repo, refresh = false)
      currepo = ensure_repo(owner, repo)
      if currepo.nil?
        warn "Could not find repo #{owner}/#{repo} for retrieving issues"
        return
      end

      raw_issues = if refresh
                     retrieve_issues(owner, repo, refresh = true)
                   else
                     issues = db[:issues].filter(:repo_id => currepo[:id]).all
                     retrieve_issues(owner, repo).reduce([]) do |acc, x|
                       if issues.find { |y| y[:issue_id] == x['number'] }.nil?
                         acc << x
                       else
                         acc
                       end
                     end
                   end

      raw_issues.map { |x| save { ensure_issue(owner, repo, x['number']) } }.select { |x| !x.nil? }
    end

    ##
    # Make sure that the issue exists
    def ensure_issue(owner, repo, issue_id, events = true,
                     comments = true, labels = true)

      issues = db[:issues]
      repository = ensure_repo(owner, repo)

      if repo.nil?
        warn "Could not find repo #{owner}/#{repo} for retrieving issue #{issue_id}"
        return
      end

      cur_issue = issues.first(:issue_id => issue_id,
                               :repo_id => repository[:id])

      retrieved = retrieve_issue(owner, repo, issue_id)

      if retrieved.nil?
        warn "Could not retrieve issue #{owner}/#{repo} -> #{issue_id}"
        return
      end

      # Pull requests and issues share the same issue_id
      pull_req = unless retrieved['pull_request'].nil? or
          retrieved['pull_request']['patch_url'].nil?
                   debug "Issue #{owner}/#{repo}->#{issue_id} is a pull request"
                   ensure_pull_request(owner, repo, issue_id, false, false, false)
                 end

      if cur_issue.nil?

        reporter = ensure_user(retrieved['user']['login'], false, false)
        assignee = unless retrieved['assignee'].nil?
                     ensure_user(retrieved['assignee']['login'], false, false)
                   end

        issues.insert(:repo_id => repository[:id],
                     :assignee_id => unless assignee.nil? then assignee[:id] end,
                     :reporter_id => reporter[:id],
                     :issue_id => issue_id,
                     :pull_request => if pull_req.nil? then false else true end,
                     :pull_request_id => unless pull_req.nil? then pull_req[:id] end,
                     :created_at => date(retrieved['created_at']))

        info "Added issue #{owner}/#{repo} -> #{issue_id}"
      else
        debug "Issue #{owner}/#{repo}->#{issue_id} exists"
        if cur_issue[:pull_request] == false and not pull_req.nil?
          info "Updated issue #{owner}/#{repo}->#{issue_id} as pull request"
          issues.filter(:issue_id => issue_id, :repo_id => repository[:id]).update(
              :pull_request => true,
              :pull_request_id => pull_req[:id])
        end
      end
      ensure_issue_events(owner, repo, issue_id) if events
      ensure_issue_comments(owner, repo, issue_id) if comments
      ensure_issue_labels(owner, repo, issue_id) if labels
      issues.first(:issue_id => issue_id,
                   :repo_id => repository[:id])
    end

    ##
    # Retrieve and process all events for an issue
    def ensure_issue_events(owner, repo, issue_id)
      currepo = ensure_repo(owner, repo)

      if currepo.nil?
        warn "Could not find repository #{owner}/#{repo} for retrieving events for issue #{issue_id}"
        return
      end

      issue = ensure_issue(owner, repo, issue_id, false, false, false)
      if issue.nil?
        warn "Could not find issue #{owner}/#{repo} -> #{issue_id} for retrieving events"
        return
      end

      retrieve_issue_events(owner, repo, issue_id).reduce([]) do |acc, x|

        if db[:issue_events].first(:issue_id => issue[:id],
                                    :event_id => x['id']).nil?
          acc << x
        else
          acc
        end
      end.map { |x|
        save{ensure_issue_event(owner, repo, issue_id, x['id'])}
      }.select{|x| !x.nil?}
    end

    ##
    # Retrieve and process +event_id+ for an +issue_id+
    def ensure_issue_event(owner, repo, issue_id, event_id)
      issue = ensure_issue(owner, repo, issue_id, false, false, false)

      if issue.nil?
        warn "Could not find issue #{owner}/#{repo} -> #{issue_id} for retrieving event #{event_id}"
        return
      end

      issue_event_str = "#{owner}/#{repo} -> #{issue_id}/#{event_id}"

      curevent = db[:issue_events].first(:issue_id => issue[:id],
                                          :event_id => event_id)
      if curevent.nil?

        retrieved = retrieve_issue_event(owner, repo, issue_id, event_id)

        if retrieved.nil?
          warn "Could not retrieve issue_event #{owner}/#{repo} -> #{issue_id}/#{issue_event_str}"
          return
        elsif retrieved['actor'].nil?
          warn "Could not find issue_event_actor #{owner}/#{repo} -> #{issue_id}/#{issue_event_str}"
          return
        end

        actor = ensure_user(retrieved['actor']['login'], false, false)

        action_specific = case retrieved['event']
                            when "referenced" then retrieved['commit_id']
                            when "merged" then retrieved['commit_id']
                            when "closed" then retrieved['commit_id']
                            else nil
                          end

        if retrieved['event'] == 'assigned'

          def update_assignee(owner, repo, issue, actor)
            db[:issues].first(:id => issue[:id]).update(:assignee_id => actor[:id])
            info "Updated #{owner}/#{repo} -> #{issue[:id]}, assignee -> #{actor[:id]}"
          end

          if issue[:assignee_id].nil? then
            update_assignee(owner, repo, issue, actor)
          else
            existing = db[:issue_events].\
                        filter(:issue_id => issue[:id],:action => 'assigned').\
                        order(Sequel.desc(:created_at)).first
            if existing.nil?
              update_assignee(owner, repo, issue, actor)
            elsif date(existing[:created_at]) < date(retrieved['created_at'])
              update_assignee(owner, repo, issue, actor)
            end
          end
        end

        db[:issue_events].insert(
            :event_id => event_id,
            :issue_id => issue[:id],
            :actor_id => unless actor.nil? then actor[:id] end,
            :action => retrieved['event'],
            :action_specific => action_specific,
            :created_at => date(retrieved['created_at']))

        info "Added issue_event #{owner}/#{repo} -> #{issue_id}/#{issue_event_str}"
        db[:issue_events].first(:issue_id => issue[:id],
                                 :event_id => event_id)
      else
        debug "Issue event #{owner}/#{repo} -> #{issue_id}/#{issue_event_str} exists"
        curevent
      end
    end

    ##
    # Retrieve and process all comments for an issue.
    # If pull_req_id is not nil this means that we are only retrieving
    # comments for the pull request discussion for projects that don't have
    # issues enabled
    def ensure_issue_comments(owner, repo, issue_id, pull_req_id = nil)
      currepo = ensure_repo(owner, repo)

      if currepo.nil?
        warn "Could not find repository #{owner}/#{repo} for retrieving issue comments for issue #{issue_id}"
        return
      end

      issue = if pull_req_id.nil?
                ensure_issue(owner, repo, issue_id, false, false, false)
              else
                db[:issues].first(:pull_request_id => pull_req_id)
              end

      if issue.nil?
        warn "Could not find issue #{owner}/#{repo} -> #{issue_id} for retrieving issue comments"
        return
      end

      retrieve_issue_comments(owner, repo, issue_id).reduce([]) do |acc, x|

        if db[:issue_comments].first(:issue_id => issue[:id],
                                    :comment_id => x['id']).nil?
          acc << x
        else
          acc
        end
      end.map { |x|
        save{ensure_issue_comment(owner, repo, issue_id, x['id'], pull_req_id)}
      }.select{|x| !x.nil?}
    end

    ##
    # Retrieve and process +comment_id+ for an +issue_id+
    def ensure_issue_comment(owner, repo, issue_id, comment_id, pull_req_id = nil)
      issue = if pull_req_id.nil?
                ensure_issue(owner, repo, issue_id, false, false, false)
              else
                db[:issues].first(:pull_request_id => pull_req_id)
              end

      if issue.nil?
        warn "Could not find issue #{owner}/#{repo} -> #{issue_id} for retrieving comment #{comment_id}"
        return
      end

      issue_comment_str = "#{owner}/#{repo} -> #{issue_id}/#{comment_id}"

      curcomment = db[:issue_comments].first(:issue_id => issue[:id],
                                          :comment_id => comment_id)
      if curcomment.nil?

        retrieved = retrieve_issue_comment(owner, repo, issue_id, comment_id)

        if retrieved.nil?
          warn "Could not retrieve issue_comment #{issue_comment_str}"
          return
        end

        user = ensure_user(retrieved['user']['login'], false, false)

        db[:issue_comments].insert(
            :comment_id => comment_id,
            :issue_id => issue[:id],
            :user_id => unless user.nil? then user[:id] end,
            :created_at => date(retrieved['created_at'])
        )

        info "Added issue_comment #{issue_comment_str}"
        db[:issue_comments].first(:issue_id => issue[:id],
                                   :comment_id => comment_id)
      else
        debug "Issue comment #{issue_comment_str} exists"
        curcomment
      end
    end

    ##
    # Retrieve repository issue labels
    def ensure_labels(owner, repo, refresh = false)
      currepo = ensure_repo(owner, repo)

      if currepo.nil?
        warn "Could not find #{owner}/#{repo} for retrieving issue labels"
        return
      end

      repo_labels = db[:repo_labels].filter(:repo_id => currepo[:id]).all

      retrieve_repo_labels(owner, repo, refresh).reduce([]) do |acc, x|
        if repo_labels.find {|y| y[:name] == x['name']}.nil?
          acc << x
        else
          acc
        end
      end.map { |x| save { ensure_repo_label(owner, repo, x['name']) } }.select { |x| !x.nil? }
    end

    ##
    # Retrieve a single repository issue label by name
    def ensure_repo_label(owner, repo, name)
      currepo = ensure_repo(owner, repo)

      if currepo.nil?
        warn "Could not find #{owner}/#{repo} for retrieving label #{name}"
        return
      end

      label = db[:repo_labels].first(:repo_id => currepo[:id], :name => name)

      if label.nil?
        retrieved = retrieve_repo_label(owner, repo, name)

        if retrieved.nil?
          warn "Could not retrieve repo_label #{owner}/#{repo} -> #{name}"
          return
        end

        db[:repo_labels].insert(
            :repo_id => currepo[:id],
            :name => name
        )

        info "Added repo_label #{owner}/#{repo} -> #{name}"
        db[:repo_labels].first(:repo_id => currepo[:id], :name => name)
      else
        label
      end
    end

    ##
    # Ensure that all labels have been assigned to the issue
    def ensure_issue_labels(owner, repo, issue_id)

      issue = ensure_issue(owner, repo, issue_id, false, false, false)

      if issue.nil?
        warn "Could not find issue #{owner}/#{repo} -> #{issue_id} for retrieving labels"
        return
      end

      issue_labels = db.from(:issue_labels, :repo_labels)\
                        .where(:issue_labels__label_id => :repo_labels__id)\
                        .where(:issue_labels__issue_id => issue[:id])\
                        .select(:repo_labels__name).all

      retrieve_issue_labels(owner, repo, issue_id).reduce([]) do |acc, x|
        if issue_labels.find {|y| y[:name] == x['name']}.nil?
          acc << x
        else
          acc
        end
      end.map { |x| save{ensure_issue_label(owner, repo, issue[:issue_id], x['name']) }}.select{|x| !x.nil?}

    end

    ##
    # Ensure that a specific label has been assigned to the issue
    def ensure_issue_label(owner, repo, issue_id, name)

      issue = ensure_issue(owner, repo, issue_id, false, false, false)

      if issue.nil?
        warn "Could not find issue #{owner}/#{repo} -> #{issue_id} to assign label #{name}"
        return
      end

      label = ensure_repo_label(owner, repo, name)

      if label.nil?
        warn "Could not find repo label #{owner}/#{repo} -> #{name}"
        return
      end

      issue_lbl = db[:issue_labels].first(:label_id => label[:id],
                                           :issue_id => issue[:id])

      if issue_lbl.nil?

        db[:issue_labels].insert(
            :label_id => label[:id],
            :issue_id => issue[:id],
        )
        info "Added issue_label #{name} to issue #{owner}/#{repo} -> #{issue_id}"
        db[:issue_labels].first(:label_id => label[:id],
                                 :issue_id => issue[:id])
      else
        debug "Issue label #{name} to issue #{owner}/#{repo} -> #{issue_id} exists"
        issue_lbl
      end

    end

    # Run a block in a DB transaction. Exceptions trigger transaction rollback
    # and are rethrown.
    def transaction(&block)
      db
      persister

      result = nil
      start_time = Time.now
      begin
        db.transaction(:rollback => :reraise, :isolation => :repeatable,
                        :retry_on => @retry_on_error, :num_retries => 3) do
          result = yield block
        end
        total = Time.now.to_ms - start_time.to_ms
        debug "Transaction committed (#{total} ms)"
        result
      rescue StandardError => e
        total = Time.now.to_ms - start_time.to_ms
        warn "Transaction failed (#{total} ms)"
        raise e
      ensure
        GC.start
      end
    end

    def save(&block)
      if config(:rescue_loops) == 'true'
        begin
          yield block
        rescue StandardError => e
          error e.message
          error e.backtrace.join("\n")
          nil
        end
      else
        yield block
      end
    end

    # Store a commit contained in a hash. First check whether the commit exists.
    def store_commit(c, repo, user)
      commits = db[:commits]
      commit = commits.first(:sha => c['sha'])

      if commit.nil?
        author = commit_user(c['author'], c['commit']['author'])
        commiter = commit_user(c['committer'], c['commit']['committer'])

        repository = ensure_repo(user, repo)

        if repository.nil?
          warn "Could not find repo #{user}/#{repo} for storing commit #{c['sha']}"
        end

        commits.insert(:sha => c['sha'],
                       :author_id => author[:id],
                       :committer_id => commiter[:id],
                       :project_id => if repository.nil? then nil else repository[:id] end ,
                       :created_at => date(c['commit']['author']['date'])
        )
        info "Added commit #{user}/#{repo} -> #{c['sha']} "
        commits.first(:sha => c['sha'])
      else
        debug "Commit #{user}/#{repo} -> #{c['sha']} exists"
        commit
      end
    end

    ##
    # Convert a string value to boolean, the SQL way
    def boolean(arg)
      case arg
        when 'true'
          1
        when 'false'
          0
        when nil
          0
      end
    end

    # Dates returned by Github are formatted as:
    # - yyyy-mm-ddThh:mm:ssZ
    # - yyyy/mm/dd hh:mm:ss {+/-}hhmm
    def date(arg)
      if arg.class != Time
        Time.parse(arg)#.to_i
      else
        arg
      end
    end

    def is_valid_email(email)
      email =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
    end

    def max(a, b)
      if a >= b
        a
      else
        b
      end
    end
  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
