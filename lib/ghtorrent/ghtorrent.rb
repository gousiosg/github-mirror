require 'sequel'

require 'ghtorrent/time'
require 'ghtorrent/logging'
require 'ghtorrent/settings'
require 'ghtorrent/retriever'
require 'ghtorrent/persister'

module GHTorrent
  class Mirror

    include GHTorrent::Logging
    include GHTorrent::Settings
    include GHTorrent::Retriever
    include GHTorrent::Persister

    attr_reader :settings, :persister, :ext_uniq, :logger

    def initialize(settings)
      @settings = settings
      @ext_uniq = config(:uniq_id)
      @logger = Logger.new(STDOUT)
      @persister = connect(:mongo, @settings)
      get_db
    end

    # db related functions
    def get_db
      Sequel.single_threaded = true
      @db = Sequel.connect(config(:sql_url), :encoding => 'utf8')
      #@db.loggers << @logger
      if @db.tables.empty?
        dir = File.join(File.dirname(__FILE__), 'migrations')
        puts "Database empty, running migrations from #{dir}"
        Sequel.extension :migration
        Sequel::Migrator.apply(@db, dir)
      end

      @db
    end

    ##
    # Ensure that a user exists, or fetch its latest state from Github
    # ==Parameters:
    #  [user] The email or login name to lookup the user by
    def get_commit(user, repo, sha)

      unless sha.match(/[a-f0-9]{40}$/)
        error "GHTorrent: Ignoring commit #{sha}"
        return
      end

      transaction do
        ensure_commit(repo, sha, user)
      end
    end

    ##
    # Add a user as member to a project
    # ==Parameters:
    #  [owner] The login of the repository owner
    #  [repo] The name of the repository
    #  [new_member] The login of the member to add
    #  [date_added] The timestamp that the add event took place
    def get_project_member(owner, repo, new_member, date_added)
      transaction do
        ensure_project_member(owner, repo, new_member, date_added)
      end
    end

    ##
    # Add a commit comment to a commit
    # ==Parameters:
    #  [user] The login of the repository owner
    #  [repo] The name of the repository
    #  [comment_id] The login of the member to add
    #  [date_added] The timestamp that the add event took place
    def get_commit_comment(user, repo, comment_id, date_added)
      transaction do
        ensure_commit_comment(user, repo, comment_id, date_added)
      end
    end

    ##
    # Add a watcher to a repository
    # ==Parameters:
    #  [owner] The login of the repository owner
    #  [repo] The name of the repository
    #  [watcher] The login of the member to add
    #  [date_added] The timestamp that the add event took place
    def get_watcher(owner, repo, watcher, date_added)
      transaction do
        ensure_watcher(owner, repo, watcher, date_added)
      end
    end

    ##
    # Add a follower to user
    # ==Parameters:
    #  [follower] The login of the repository owner
    #  [followed] The name of the repository
    #  [date_added] The timestamp that the add event took place
    def get_follower(follower, followed, date_added)
      transaction do
        ensure_user_follower(followed, follower, date_added)
      end
    end

    ##
    # Get a pull request and record the changes it affects
    # ==Parameters:
    #  [owner] The owner of the repository to which the pullreq will be applied
    #  [repo] The repository to which the pullreq will be applied
    #  [pullreq_id] The ID of the pull request relative to the repository
    def get_pull_request(owner, repo, pullreq_id)
      transaction do
        ensure_pull_request(owner, repo, pullreq_id)
      end
    end

    ##
    # Retrieve details about a project fork (including the forked project)
    # ==Parameters:
    #  [owner] The login of the repository owner
    #  [repo] The name of the repository
    #  [fork_id] The fork item id
    #  [date_added] The timestamp that the add event took place
    def get_fork(owner, repo, fork_id, date_added)
      transaction do
        ensure_fork(owner, repo, fork_id, date_added)
      end
    end

    ##
    # Make sure a commit exists
    #
    def ensure_commit(repo, sha, user, comments = true)
      ensure_repo(user, repo)
      c = retrieve_commit(repo, sha, user)

      if c.nil?
        warn "GHTorrent: Commit #{user}/#{repo} -> #{sha} does not exist"
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
    # Get as many commits for a repository as allowed by Github
    #
    # ==Parameters:
    # [user]  The user to whom the repo belongs.
    # [repo]  The repo to look for commits into.
    def ensure_commits(user, repo)
      userid = @db[:users].filter(:login => user).first[:id]
      repoid = @db[:projects].filter(:owner_id => userid,
                                     :name => repo).first[:id]

      latest = @db[:commits].filter(:project_id => repoid).order(:created_at).last
      commits = if latest.nil?
                  retrieve_commits(repo, nil, user)
                else
                  retrieve_commits(repo, latest[:sha], user)
                end

      commits.map do |c|
        ensure_commit(repo, c['sha'], user)
      end
    end

    ##
    # Get the parents for a specific commit. The commit must be first stored
    # in the database.
    def ensure_parents(commit)
      commits = @db[:commits]
      commit['parents'].each do |p|
          parents =  @db[:commit_parents]
          url = p['url'].split(/\//)
          this = commits.first(:sha => commit['sha'])
          parent = commits.first(:sha => url[7])

          if parent.nil?
            store_commit(retrieve_commit(url[5], url[7], url[4]), url[5], url[4])
            parent = commits.first(:sha => url[7])
          end

          if parents.first(:commit_id => this[:id],
                           :parent_id => parent[:id]).nil?

            parents.insert(:commit_id => this[:id],
                           :parent_id => parent[:id])
            info "GHTorrent: Added parent #{parent[:sha]} to commit #{this[:sha]}"
          else
            debug "GHTorrent: Parent #{parent[:sha]} for commit #{this[:sha]} exists"
          end
        end
    end

    ##
    # Make sure that a commit has been associated with the provided repo
    # ==Parameters:
    #  [user] The user that owns the repo this commit has been submitted to
    #  [repo] The repo receiving the commit
    #  [sha] The commit SHA
    def ensure_repo_commit(user, repo, sha)
      userid = @db[:users].first(:login => user)[:id]
      projectid = @db[:projects].first(:owner_id => userid,
                                     :name => repo)[:id]
      commitid = @db[:commits].first(:sha => sha)[:id]

      exists = @db[:project_commits].first(:project_id => projectid,
                                           :commit_id => commitid)
      if exists.nil?
        @db[:project_commits].insert(
            :project_id => projectid,
            :commit_id => commitid
        )
        info "GHTorrent: Added commit #{user}/#{repo} -> #{sha}"
        @db[:project_commits].first(:project_id => projectid,
                                    :commit_id => commitid)
      else
        debug "GHTorrent: Commit #{user}/#{repo} -> #{sha} exists"
        exists
      end
    end

    ##
    # Add (or update) an entry for a commit author. This method uses information
    # in the JSON object returned by Github to add (or update) a user in the
    # metadata database with a full user entry (both Git and Github details).
    # Resolution of how
    #
    # ==Parameters:
    # [githubuser]  A hash containing the user's Github login
    # [commituser]  A hash containing the Git commit's user name and email
    # == Returns:
    # The (added/modified) user entry as a Hash.
    def commit_user(githubuser, commituser)

      raise GHTorrentException.new "git user is null" if commituser.nil?

      users = @db[:users]

      name = commituser['name']
      email = commituser['email'] #if is_valid_email(commituser['email'])
      # Github user can be null when the commit email has not been associated
      # with any account in Github.
      login = githubuser['login'] unless githubuser.nil?

      if login.nil?
        ensure_user("#{name}<#{email}>", false, false)
      else
        dbuser = users.first(:login => login)
        byemail = users.first(:email => email)
        if dbuser.nil?
          # We do not have the user in the database yet. Add him
          added = ensure_user(login, false, false)
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
    def ensure_user(user, followers, orgs)
      # Github only supports alpa-nums and dashes in its usernames.
      # All other sympbols are treated as emails.
      if not user.match(/^[A-Za-z0-9\-]*$/)
        begin
          name, email = user.split("<")
          email = email.split(">")[0]
        rescue Exception
          raise new GHTorrentException("Not a valid email address: #{user}")
        end
        u = ensure_user_byemail(email.strip, name.strip)
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
      users = @db[:users]
      usr = users.first(:login => user)

      if usr.nil?
        u = retrieve_user_byusername(user)

        if u.nil?
          warn "GHTorrent: User #{user} does not exist"
          return
        end

        email = unless u['email'].nil?
                  if u['email'].strip == "" then
                    nil
                  else
                    u['email'].strip
                  end
                end

        users.insert(:login => u['login'],
                     :name => u['name'],
                     :company => u['company'],
                     :email => email,
                     :location => u['location'],
                     :type => user_type(u['type']),
                     :created_at => date(u['created_at']),
                     :ext_ref_id => u[@ext_uniq])

        info "GHTorrent: New user #{user}"
        users.first(:login => user)
      else
        debug "GHTorrent: User #{user} exists"
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
    def ensure_user_followers(followed, date_added = nil)
      time = Time.now
      curuser = @db[:users].first(:login => followed)
      followers = @db.from(:followers, :users).\
          where(:followers__follower_id => :users__id).
          where(:followers__user_id => curuser[:id]).select(:login).all

      retrieve_user_followers(followed).reduce([]) do |acc, x|
        if followers.find {|y| y[:login] == x['login']}.nil?
          acc << x
        else
          acc
        end
      end.map { |x| ensure_user_follower(followed, x['login'], time) }
    end

    ##
    # Make sure that a user follows another one
    def ensure_user_follower(followed, follower, date_added)
      follower_user = ensure_user(follower, false, false)
      followed_user = ensure_user(followed, false, false)

      if followed_user.nil? or follower_user.nil?
        warn "Could not add follower #{follower} to #{followed}"
        return
      end

      followers = @db[:followers]
      followed_id = follower_user[:id]
      follower_id = followed_user[:id]

      follower_exists = followers.first(:user_id => followed_id,
                                        :follower_id => follower_id)

      if follower_exists.nil?
        added = if date_added.nil? then Time.now else date_added end
        retrieved = retrieve_user_follower(followed, follower)

        if retrieved.nil?
          warn "Follower #{follower} does not exist for user #{followed}"
          return
        end

        followers.insert(:user_id => followed_id,
                         :follower_id => follower_id,
                         :created_at => added,
                         :ext_ref_id => retrieved[@ext_uniq])
        info "GHTorrent: User #{follower} follows #{followed}"
      else
        unless date_added.nil?
          followers.filter(:user_id => followed_id,
                           :follower_id => follower_id)\
                    .update(:created_at => date(date_added))
          debug "GHTorrent: Updating follower #{followed} -> #{follower}"
        end
      end
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
      users = @db[:users]
      usr = users.first(:email => email)

      if usr.nil?

        u = retrieve_user_byemail(email, name)

        if u.nil? or u['login'].nil?
          debug "GHTorrent: Cannot find #{email} through search API query"
          login = (0...8).map { 65.+(rand(25)).chr }.join
          users.insert(:email => email,
                       :name => name,
                       :login => login,
                       :created_at => Time.now,
                       :ext_ref_id => ""
          )
          info "GHTorrent: Added fake user #{login} -> #{email}"
          users.first(:login => login)
        else
          users.insert(:login => u['login'],
                       :name => u['name'],
                       :company => u['company'],
                       :email => u['email'],
                       :location => u['location'],
                       :created_at => date(u['created_at']),
                       :ext_ref_id => u[@ext_uniq])
          info "GHTorrent: Found #{email} through search API query"
          users.first(:login => u['login'])
        end
      else
        debug "GHTorrent: User with email #{email} exists"
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
    def ensure_repo(user, repo, commits = true, project_members = true, watchers = true)

      ensure_user(user, false, false)
      repos = @db[:projects]
      curuser = @db[:users].first(:login => user)
      currepo = repos.first(:owner_id => curuser[:id], :name => repo)

      if currepo.nil?
        r = retrieve_repo(user, repo)

        if r.nil?
          warn "Repo #{user}/#{repo} does not exist"
          return
        end

        repos.insert(:url => r['url'],
                     :owner_id => @db[:users].filter(:login => user).first[:id],
                     :name => r['name'],
                     :description => r['description'],
                     :language => r['language'],
                     :created_at => date(r['created_at']),
                     :ext_ref_id => r[@ext_uniq])

        info "GHTorrent: New repo #{repo}"
        ensure_commits(user, repo) if commits
        ensure_project_members(user, repo) if project_members
        ensure_watchers(user, repo) if watchers
        repos.first(:owner_id => curuser[:id], :name => repo)
      else
        debug "GHTorrent: Repo #{repo} exists"
        currepo
      end
    end

    ##
    # Make sure that a project has all the registered members defined
    def ensure_project_members(user, repo)
      time = Time.now
      curuser = @db[:users].first(:login => user)
      currepo = @db[:projects].first(:owner_id => curuser[:id], :name => repo)
      project_members = @db.from(:project_members, :users).\
          where(:project_members__user_id => :users__id).\
          where(:project_members__repo_id => currepo[:id]).select(:login).all

      retrieve_repo_collaborators(user, repo).reduce([]) do |acc, x|
        if project_members.find {|y| y[:login] == x['login']}.nil?
          acc << x
        else
          acc
        end
      end.map { |x| ensure_project_member(user, repo, x['login'], time) }
    end

    ##
    # Make sure that a project member exists in a project
    def ensure_project_member(owner, repo, new_member, date_added)
      pr_members = @db[:project_members]
      project = ensure_repo(owner, repo, true, false, true)
      new_user = ensure_user(new_member, false, false)

      if project.nil? or new_user.nil?
        return
      end

      memb_exist = pr_members.first(:user_id => new_user[:id],
                                    :repo_id => project[:id])

      if memb_exist.nil?
        added = if date_added.nil? then Time.now else date_added end
        retrieved = retrieve_repo_collaborator(owner, repo, new_member)

        if retrieved.nil?
          warn "Project member #{new_member} does not exist in #{owner}/#{repo}"
          return
        end

        pr_members.insert(
            :user_id => new_user[:id],
            :repo_id => project[:id],
            :created_at => date(added),
            :ext_ref_id => retrieved[@ext_uniq]
        )
        info "GHTorrent: Added project member #{repo} -> #{new_member}"
      else
        unless date_added.nil?
          pr_members.filter(:user_id => new_user[:id],
                            :repo_id => project[:id])\
                    .update(:created_at => date(date_added))
          info "GHTorrent: Updating  #{repo} -> #{new_member}"
        end
      end
    end

    ##
    # Make sure that the organizations the user participates into exist
    #
    # ==Parameters:
    # [user]  The login name of the user to check the organizations for
    #
    def ensure_orgs(user)
      retrieve_orgs(user).map{|o| ensure_participation(user, o['login'])}
    end

    ##
    # Make sure that a user participates to the provided organization
    #
    # ==Parameters:
    # [user] The login name of the user to check the organizations for
    # [org]  The login name of the organization to check whether the user
    #        belongs in
    #
    def ensure_participation(user, organization)
      org = ensure_org(organization)
      usr = ensure_user(user, false, false)

      org_members = @db[:organization_members]
      participates = org_members.first(:user_id => usr[:id], :org_id => org[:id])

      if participates.nil?
        org_members.insert(:user_id => usr[:id],
                           :org_id => org[:id])
        info "GHTorrent: Added participation #{organization} -> #{user}"
        org_members.first(:user_id => usr[:id], :org_id => org[:id])
      else
        debug "GHTorrent: Participation #{organization} -> #{user} exists"
        participates
      end

    end

    ##
    # Make sure that an organization exists
    #
    # ==Parameters:
    # [organization]  The login name of the organization
    #
    def ensure_org(organization)
      org = @db[:users].find(:login => organization, :type => 'org')

      if org.nil?
        ensure_user(org, false, false)
      else
        debug "GHTorrent: Organization #{organization} exists"
        org.first
      end
    end

    ##
    # Get all comments for a commit
    #
    # ==Parameters:
    # [user]  The login name of the organization
    # [user]  The repository containing the commit whose comments will be retrieved
    # [sha]  The commit sha to retrieve comments for
    def ensure_commit_comments(user, repo, sha)
      commit_id = @db[:commits].first(:sha => sha)[:id]
      stored_comments = @db[:commit_comments].filter(:commit_id => commit_id)
      commit_comments = retrieve_commit_comments(user, repo, sha)

      not_saved = commit_comments.reduce([]) do |acc, x|
        if stored_comments.find{|y| y[:comment_id] == x['id']}.nil?
          acc << x
        else
          acc
        end
      end

      not_saved.map{|x| ensure_commit_comment(user, repo, x['id'], nil)}
    end

    ##
    # Get a specific comment
    #
    # ==Parameters:
    # [user]  The login name of the organization
    # [repo]  The repository containing the commit whose comment will be retrieved
    # [id]  The comment id to retrieve
    # [created_at]  The timestamp that the comment was made.
    def ensure_commit_comment(user, repo, id, created_at)
      stored_comment = @db[:commit_comments].first(:comment_id => id)

      if stored_comment.nil?
        retrieved = retrieve_commit_comment(user, repo, id)

        if retrieved.nil?
          warn "GHTorrent: Commit comment #{id} deleted"
          return
        end

        commit = ensure_commit(repo, retrieved['commit_id'], user, false)
        user = ensure_user(user, false, false)
        @db[:commit_comments].insert(
            :commit_id => commit[:id],
            :user_id => user[:id],
            :body => retrieved['body'],
            :line => retrieved['line'],
            :position => retrieved['position'],
            :comment_id => retrieved['id'],
            :ext_ref_id => retrieved[@ext_uniq],
            :created_at => date(retrieved['created_at'])
        )
        info "GHTorrent: Added commit comment #{commit[:sha]} -> #{user[:login]}"
      else
        unless created_at.nil?
          @db[:commit_comments].filter(:comment_id => id)\
                               .update(:created_at => date(created_at))
          info "GHTorrent: Updating comment #{user}/#{repo} -> #{id}"
        end
        info "GHTorrent: Commit comment #{id} exists"
      end
      @db[:commit_comments].first(:comment_id => id)
    end

    ##
    # Make sure that
    def ensure_watchers(owner, repo)
      time = Time.now
      currepo = ensure_repo(owner, repo, true, true, false)

      if currepo.nil?
        warn "Could not retrieve watchers for #{owner}/#{repo}"
        return
      end

      watchers = @db.from(:watchers, :users).\
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
      end.map { |x| ensure_watcher(owner, repo, x['login'], time) }
    end

    ##
    # Make sure that a project member exists in a project
    def ensure_watcher(owner, repo, watcher, date_added = nil)
      project = ensure_repo(owner, repo, false, false, false)
      new_watcher = ensure_user(watcher, false, false)

      if new_watcher.nil? or project.nil?
        warn "GHTorrent: Watcher #{watcher} does not exist"
        return
      end

      watchers = @db[:watchers]
      memb_exist = watchers.first(:user_id => new_watcher[:id],
                                  :repo_id => project[:id])

      if memb_exist.nil?
        added = if date_added.nil? then Time.now else date_added end
        retrieved = retrieve_watcher(owner, repo, watcher)

        if retrieved.nil?
          warn "Watcher #{watcher} no longer watches #{owner}/#{repo}"
          return
        end

        watchers.insert(
            :user_id => new_watcher[:id],
            :repo_id => project[:id],
            :created_at => date(added),
            :ext_ref_id => retrieved[@ext_uniq]
        )
        info "GHTorrent: Added watcher #{repo} -> #{watcher}"
      else
        unless date_added.nil?
          watchers.filter(:user_id => new_watcher[:id],
                          :repo_id => project[:id])\
                  .update(:created_at => date(date_added))
          info "GHTorrent: Updating  #{repo} -> #{watcher}"
        end
      end
    end

    ##
    # Process all pull requests
    def ensure_pull_requests(owner, repo)
      currepo = ensure_repo(owner, repo, false, false, false)
      if currepo.nil?
        warn "Could not retrieve pull requests from #{owner}/#{repo}"
        return
      end

      pull_reqs = @db[:pull_requests].filter(:base_repo_id => currepo[:id])

      retrieve_pull_requests(owner, repo).reduce([]) do |acc, x|
        if pull_reqs.find { |y| y[:pullreq_id] == x['number'] }.nil?
          acc << x
        else
          acc
        end
      end.map { |x| ensure_pull_request(owner, repo, x['number']) }
    end

    ##
    # Process a pull request
    def ensure_pull_request(owner, repo, pullreq_id, comments = true, commits = true)
      pulls_reqs = @db[:pull_requests]
      pull_req_history = @db[:pull_request_history]

      project = ensure_repo(owner, repo, false, false, false)

      if project.nil?
        return
      end

      # Adds a pull request history event
      add_history = Proc.new do |id, ts, unq, act|

        entry = pull_req_history.first(:pull_request_id => id, :created_at => ts,
                                       :ext_ref_id => unq, :action => act)
        if entry.nil?
          pull_req_history.insert(:pull_request_id => id, :created_at => ts,
                                  :ext_ref_id => unq, :action => act)
          info "GHTorrent: New pull request (#{id}) history entry (#{act})"
        end
      end

      is_intra_branch = Proc.new do |req|
        req['head']['repo'].nil?
      end

      log_msg = Proc.new do |req|
        head = if is_intra_branch.call(req)
                 req['base']['repo']['full_name']
               else
                 req['head']['repo']['full_name']
               end

        <<-eos.gsub(/\s+/, " ").strip
            GHTorrent: Pull request #{pullreq_id}
            #{head} -> #{req['base']['repo']['full_name']}
        eos
      end

      pull_req_exists = pulls_reqs.first(:base_repo_id => project[:id],
                                         :pullreq_id => pullreq_id)

      if pull_req_exists.nil?

        retrieved = retrieve_pull_request(owner, repo, pullreq_id)

        if retrieved.nil?
          warn "GHTorrent: Cannot retrieve pull request (#{owner}/#{repo} #{pullreq_id})"
          return
        end

        # Pull requests might be deleted between publishing them and
        # processing them...
        if retrieved['head']['repo'].nil?
          head_repo = head_commit = nil
          warn "GHTorrent: Pull request head repo #{owner}/#{repo} deleted."
        else

          head_repo = ensure_repo(retrieved['head']['repo']['owner']['login'],
                                  retrieved['head']['repo']['name'],
                                  false, false, false)

          head_commit = ensure_commit(retrieved['head']['repo']['name'],
                                      retrieved['head']['sha'],
                                      retrieved['head']['repo']['owner']['login'])
        end

        base_repo = ensure_repo(retrieved['base']['repo']['owner']['login'],
                                retrieved['base']['repo']['name'],
                                false, false, false)

        base_commit = ensure_commit(retrieved['base']['repo']['name'],
                                    retrieved['base']['sha'],
                                    retrieved['base']['repo']['owner']['login']
                                    )

        pull_req_user = ensure_user(retrieved['user']['login'], false, false)

        merged = if retrieved['merged_at'].nil? then false else true end
        closed = if retrieved['closed_at'].nil? then false else true end

        pulls_reqs.insert(
            :head_repo_id => if not head_repo.nil? then head_repo[:id] end,
            :base_repo_id => base_repo[:id],
            :head_commit_id => if not head_commit.nil? then head_commit[:id] end,
            :base_commit_id => base_commit[:id],
            :user_id => pull_req_user[:id],
            :pullreq_id => pullreq_id,
            :intra_branch => is_intra_branch.call(retrieved)
        )

        new_pull_req = pulls_reqs.first(:base_repo_id => project[:id],
                                        :pullreq_id => pullreq_id)

        add_history.call(new_pull_req[:id], date(retrieved['created_at']),
                         retrieved[@ext_uniq], 'opened')
        add_history.call(new_pull_req[:id], date(retrieved['merged_at']),
                         retrieved[@ext_uniq], 'merged') if merged
        add_history.call(new_pull_req[:id], date(retrieved['closed_at']),
                         retrieved[@ext_uniq], 'closed') if closed

        info log_msg.call(retrieved)
      else
        # A new pull request event for an existing pull request denotes
        # an update to the pull request status. Retrieve the pull request
        # and update accordingly.
        retrieved = retrieve_pull_request(owner, repo, pullreq_id)

        merged = if retrieved['merged_at'].nil? then false else true end
        closed = if retrieved['closed_at'].nil? then false else true end

        add_history.call(pull_req_exists[:id], date(retrieved['merged_at']),
                         retrieved[@ext_uniq], 'merged') if merged

        add_history.call(pull_req_exists[:id], date(retrieved['closed_at']),
                         retrieved[@ext_uniq], 'closed') if closed

        debug log_msg.call(retrieved) + " exists"
      end

      ensure_pull_request_commits(owner, repo, pullreq_id) if commits
      ensure_pull_request_comments(owner, repo, pullreq_id) if comments

      pulls_reqs.first(:base_repo_id => project[:id],
                       :pullreq_id => pullreq_id)
    end

    def ensure_pull_request_comments(owner, repo, pullreq_id, date_added = nil)

    end

    def ensure_pull_request_commits(owner, repo, pullreq_id)
      retrieve_pull_req_commits(owner, repo, pullreq_id).map {|c|
        ensure_commit(repo, c['sha'], owner, true)
      }.map { |c|
        pullreq = ensure_pull_request(owner, repo, pullreq_id, false, false)
        exists = @db[:pull_request_commits].first(:pull_request_id => pullreq[:id],
                                                  :commit_id => c[:id])
        if exists.nil?
          @db[:pull_request_commits].insert(:pull_request_id => pullreq[:id],
                                            :commit_id => c[:id])

          info "GHTorrent: Added commit #{c[:sha]} to pullreq #{owner}/#{repo} -> #{pullreq_id}"
        else
          debug "GHTorrent: Commit #{c[:sha]} exists in pullreq #{owner}/#{repo} -> #{pullreq_id}"
          exists
        end
      }
    end

    ##
    # Get all forks for a project.
    #
    # ==Parameters:
    # [owner]  The user to which the project belongs
    # [repo]  The repository/project to find forks for
    def ensure_forks(owner, repo)
      time = Time.now
      currepo = ensure_repo(owner, repo, false, false, false)

      if currepo.nil?
        warn "Could not retrieve forks for #{owner}/#{repo}"
        return
      end

      existing_forks = @db.from(:forks, :projects).\
          where(:forks__forked_project_id => :projects__id). \
          where(:forks__forked_from_id => currepo[:id]).select(:name, :login).all

      retrieve_forks(owner, repo).reduce([]) do |acc, x|
        if existing_forks.find {|y|
          y[:login] == x['owner']['login'] && y[:name] == x['name']
        }.nil?
          acc << x
        else
          acc
        end
      end.map { |x| ensure_fork(owner, repo, x['id'], time) }
    end

    ##
    # Make sure that a fork is retrieved for a project
    def ensure_fork(owner, repo, fork_id, date_added = nil)

      forks = @db[:forks]
      forked = ensure_repo(owner, repo, false, false, false)
      fork_exists = forks.first(:fork_id => fork_id)

      if fork_exists.nil?
        added = if date_added.nil? then Time.now else date_added end
        retrieved = retrieve_fork(owner, repo, fork_id)

        if retrieved.nil?
          warn "GHTorrent: Fork #{fork_id} does not exist for #{owner}/#{repo}"
          return
        end

        forked_repo_owner = retrieved['full_name'].split(/\//)[0]
        forked_repo_name = retrieved['full_name'].split(/\//)[1]

        fork = ensure_repo(forked_repo_owner, forked_repo_name)

        if forked.nil? or fork.nil?
          warn "Could not add fork #{fork_id}"
          return
        end

        forks.insert(:forked_project_id => fork[:id],
                     :forked_from_id => forked[:id],
                     :fork_id => fork_id,
                     :created_at => added,
                     :ext_ref_id => retrieved[@ext_uniq])
        info "GHTorrent: Added #{forked_repo_owner}/#{forked_repo_name} as fork of  #{owner}/#{repo}"
      else
        unless date_added.nil?
          forks.filter(:fork_id => fork_id)\
               .update(:created_at => date(date_added))
          debug "GHTorrent: Updating fork #{owner}/#{repo} (#{fork_id})"
        end
      end
    end

    private

    # Store a commit contained in a hash. First check whether the commit exists.
    def store_commit(c, repo, user)
      commits = @db[:commits]
      commit = commits.first(:sha => c['sha'])

      if commit.nil?
        author = commit_user(c['author'], c['commit']['author'])
        commiter = commit_user(c['committer'], c['commit']['committer'])

        repository = ensure_repo(user, repo, false, false, false)

        if repository.nil?
          warn "Could not store commit #{user}/#{repo} #{c['sha']}"
          return
        end

        commits.insert(:sha => c['sha'],
                       :author_id => author[:id],
                       :committer_id => commiter[:id],
                       :project_id => repository[:id],
                       :created_at => date(c['commit']['author']['date']),
                       :ext_ref_id => c[@ext_uniq]
        )
        debug "GHTorrent: New commit #{user}/#{repo} -> #{c['sha']} "
        commits.first(:sha => c['sha'])
      else
        debug "GHTorrent: Commit #{user}/#{repo} -> #{c['sha']} exists"
        commit
      end
    end

    # Run a block in a DB transaction. Exceptions trigger transaction rollback
    # and are rethrown.
    def transaction(&block)
      @db ||= get_db
      start_time = Time.now
      begin
        @db.transaction(:rollback => :reraise, :isolation => :committed) do
          yield block
        end
        total = Time.now.to_ms - start_time.to_ms
        debug "GHTorrent: Transaction committed (#{total} ms)"
      rescue Exception => e
        total = Time.now.to_ms - start_time.to_ms
        warn "GHTorrent: Transaction failed (#{total} ms)"
        raise e
      ensure
        @db.disconnect
        @db = nil
        GC.start
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
  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
