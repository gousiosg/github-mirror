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
        ensure_repo(user, repo)
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
        ensure_repo(owner, repo)
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
        ensure_repo(user, repo)
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
        ensure_repo(owner, repo)
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
        ensure_user(follower, false, false)
        ensure_user(followed, false, false)
        ensure_user_followers(followed, date_added)
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
        ensure_repo(owner, repo)
        ensure_pull_request(owner, repo, pullreq_id)
      end
    end

    ##
    # Make sure a commit exists
    #
    def ensure_commit(repo, sha, user, comments = true)
      c = retrieve_commit(repo, sha, user)
      stored = store_commit(c, repo, user)
      ensure_parents(c)
      if not c['commit']['comment_count'].nil? \
         and c['commit']['comment_count'] > 0
        ensure_commit_comments(user, repo, sha) if comments
      end
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
            info "Added parent #{parent[:sha]} to commit #{this[:sha]}"
          else
            info "Parent #{parent[:sha]} for commit #{this[:sha]} exists"
          end
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
        ensure_user("#{name}<#{email}>", true, false)
      else
        dbuser = users.first(:login => login)
        byemail = users.first(:email => email)
        if dbuser.nil?
          # We do not have the user in the database yet. Add him
          added = ensure_user(login, true, false)
          if byemail.nil?
            #
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
                :hireable => added['hireable'],
                :bio => (added['bio'][0..254] unless added['bio'].nil?),
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
        email = unless u['email'].nil?
                  if u['email'].strip == "" then
                    nil
                  else
                    u['email'].strip
                  end
                end

        if not email.nil?
          # Check whether a user has been added by email before
          byemail = users.first(:email => email)
          unless byemail.nil?
            users.filter(:email => email).update(:login => u['login'],
                           :name => u['name'],
                           :company => u['company'],
                           :hireable => boolean(u['hirable']),
                           :bio => (u['bio'][0..254] unless u['bio'].nil?),
                           :location => u['location'],
                           :type => user_type(u['type']),
                           :created_at => date(u['created_at']),
                           :ext_ref_id => u[@ext_uniq]
            )
            info "GHTorrent: Updating user #{user} (email #{email})"
          else
            users.insert(:login => u['login'],
                         :name => u['name'],
                         :company => u['company'],
                         :email => email,
                         :hireable => boolean(u['hirable']),
                         :bio => (u['bio'][0..254] unless u['bio'].nil?),
                         :location => u['location'],
                         :type => user_type(u['type']),
                         :created_at => date(u['created_at']),
                         :ext_ref_id => u[@ext_uniq])

            info "GHTorrent: New user #{user}"
          end
        else
          users.insert(:login => u['login'],
                       :name => u['name'],
                       :company => u['company'],
                       :email => email,
                       :hireable => boolean(u['hirable']),
                       :bio => (u['bio'][0..254] unless u['bio'].nil?),
                       :location => u['location'],
                       :type => user_type(u['type']),
                       :created_at => date(u['created_at']),
                       :ext_ref_id => u[@ext_uniq])

          info "GHTorrent: New user #{user}"
        end
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
    def ensure_user_followers(user, date_added = nil)
      followers = @db[:followers]
      userid = @db[:users].first(:login => user)[:id]

      retrieved = retrieve_user_followers(user)
      retrieved.each { |f|
        follower = f['login']
        ensure_user(user, false, false)
        ensure_user(follower, false, false)

        followerid = @db[:users].first(:login => follower)[:id]


        if followers.first(:user_id => userid, :follower_id => followerid).nil?
          added = if date_added.nil? then Time.now else date_added end
          followers.insert(:user_id => userid,
                           :follower_id => followerid,
                           :created_at => added,
                           :ext_ref_id => f[@ext_uniq]
          )
          info "GHTorrent: User #{follower} follows #{user}"
        else
          unless date_added.nil?
            followers.filter(:user_id => userid,
                             :follower_id => followerid).\
                      update(:created_at => date(date_added))
            info "GHTorrent: Updated follower #{follower} -> #{user}"
          end
          debug "GHTorrent: User #{follower} already follows #{user}"
        end
      }
    end

    ##
    # Try to retrieve a user by email. Search the DB first, fall back to
    # Github search API if unsuccessful.
    #
    # ==Parameters:
    # [email]  The email to lookup the user by
    # [email]  The user's name
    # [followers]  If true, the user's followers will be retrieved
    # == Returns:
    # If the user can be retrieved, it is returned as a Hash. Otherwise,
    # the result is nil
    def ensure_user_byemail(email, name)
      users = @db[:users]
      usr = users.first(:email => email)

      if usr.nil?

        u = retrieve_user_byemail(email, name)

        if u.nil? or u['user'].nil? or u['user']['login'].nil?
          debug "GHTorrent: Cannot find #{email} through search API query"
          users.insert(:email => email,
                       :name => name,
                       :login => (0...8).map { 65.+(rand(25)).chr }.join,
                       :created_at => Time.now,
                       :ext_ref_id => ""
          )
          users.first(:email => email)
        else
          users.insert(:login => u['user']['login'],
                       :name => u['user']['name'],
                       :company => u['user']['company'],
                       :email => u['user']['email'],
                       :hireable => nil,
                       :bio => nil,
                       :location => u['user']['location'],
                       :created_at => date(u['user']['created_at']),
                       :ext_ref_id => u[@ext_uniq])
          debug "GHTorrent: Found #{email} through search API query"
          users.first(:email => email)
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
    def ensure_repo(user, repo)

      ensure_user(user, true, true)
      repos = @db[:projects]
      curuser = @db[:users].first(:login => user)
      currepo = repos.first(:owner_id => curuser[:id], :name => repo)

      if currepo.nil?
        r = retrieve_repo(user, repo)
        repos.insert(:url => r['url'],
                     :owner_id => @db[:users].filter(:login => user).first[:id],
                     :name => r['name'],
                     :description => r['description'],
                     :language => r['language'],
                     :created_at => date(r['created_at']),
                     :ext_ref_id => r[@ext_uniq])

        info "GHTorrent: New repo #{repo}"
        ensure_commits(user, repo)
        ensure_project_members(user, repo)
        ensure_watchers(user, repo)
        repos.first(:owner_id => curuser[:id], :name => repo)
      else
        debug "GHTorrent: Repo #{repo} exists"
        currepo
      end
    end

    ##
    # Make sure that a project has all the registered members defined
    def ensure_project_members(user, repo)
      curuser = @db[:users].first(:login => user)
      currepo = @db[:projects].first(:owner_id => curuser[:id], :name => repo)
      project_members = @db[:project_members].filter(:repo_id => currepo[:id])

      retrieve_repo_collaborators(user, repo).reduce([]) do |acc, x|
        if project_members.find { |y| y[:login] == x['login'] }.nil?
          acc << x
        else
          acc
        end
      end.map { |x| ensure_project_member(user, repo, x['login'], nil) }
    end

    ##
    # Make sure that a project member exists in a project
    def ensure_project_member(owner, repo, new_member, date_added)
      pr_members = @db[:project_members]
      new_user = ensure_user(new_member, false, false)
      owner_id = @db[:users].first(:login => owner)[:id]
      project = @db[:projects].first(:owner_id => owner_id, :name => repo)

      memb_exist = pr_members.first(:user_id => new_user[:id],
                                    :repo_id => project[:id])

      if memb_exist.nil?
        added = if date_added.nil? then Time.now else date_added end
        retrieved = retrieve_repo_collaborator(owner, repo, new_member)

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
      #user_id = @db[:users].first(:login => user)[:id]

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
          debug "GHTorrent: Commit comment #{id} deleted"
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
        @db[:commit_comments].first(:comment_id => id)
      else
        info "GHTorrent: Commit comment #{id} exists"
        stored_comment
      end
    end

    ##
    # Make sure that
    def ensure_watchers(owner, repo)
      curuser = @db[:users].first(:login => owner)
      currepo = @db[:projects].first(:owner_id => curuser[:id],
                                     :name => repo)
      watchers = @db[:watchers].filter(:repo_id => currepo[:id])

      retrieve_watchers(owner, repo).reduce([]) do |acc, x|
        if watchers.find { |y| y[:login] == x['login'] }.nil?
          acc << x
        else
          acc
        end
      end.map { |x| ensure_watcher(owner, repo, x['login']) }
    end

    ##
    # Make sure that a project member exists in a project
    def ensure_watcher(owner, repo, watcher, date_added = nil)
      watchers = @db[:watchers]
      new_watcher = ensure_user(watcher, false, false)
      owner_id = @db[:users].first(:login => owner)[:id]
      project = @db[:projects].first(:owner_id => owner_id, :name => repo)

      memb_exist = watchers.first(:user_id => new_watcher[:id],
                                  :repo_id => project[:id])

      if memb_exist.nil?
        added = if date_added.nil? then Time.now else date_added end
        retrieved = retrieve_watcher(owner, repo, watcher)
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
      curuser = @db[:users].first(:login => owner)
      currepo = @db[:projects].first(:owner_id => curuser[:id],
                                     :name => repo)
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
    def ensure_pull_request(owner, repo, pullreq_id)
      pulls_reqs = @db[:pull_requests]
      pull_req_history = @db[:pull_request_history]
      owner_id = @db[:users].first(:login => owner)[:id]
      project = @db[:projects].first(:owner_id => owner_id, :name => repo)

      # Adds a pull request history event
      add_history = Proc.new do |id, ts, unq, act|
        pull_req_history.insert(
            :pull_request_id => id,
            :created_at => ts,
            :ext_ref_id => unq,
            :action => act
        )
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
                                  retrieved['head']['repo']['name'])

          head_commit = ensure_commit(retrieved['head']['repo']['name'],
                                      retrieved['head']['sha'],
                                      retrieved['head']['repo']['owner']['login'])
        end

        base_repo = ensure_repo(retrieved['base']['repo']['owner']['login'],
                                retrieved['base']['repo']['name'])

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
            :pullreq_id => pullreq_id
        )

        new_pull_req = pulls_reqs.first(:base_repo_id => project[:id],
                                        :pullreq_id => pullreq_id)

        add_history.call(new_pull_req[:id], date(retrieved['created_at']),
                         retrieved[@ext_uniq], 'opened')
        add_history.call(new_pull_req[:id], date(retrieved['merged_at']),
                         retrieved[@ext_uniq], 'merged') if merged
        add_history.call(new_pull_req[:id], date(retrieved['closed_at']),
                         retrieved[@ext_uniq], 'closed') if closed
      else
        retrieved = retrieve_pull_request(owner, repo, pullreq_id).sort { |x, y|
          date(x['updated_at']).to_i <=> date(y['updated_at']).to_i
        }.last

        merged = if retrieved['merged_at'].nil? then false else true end
        closed = if retrieved['closed_at'].nil? then false else true end

        add_history.call(new_pull_req[:id], date(retrieved['merged_at']),
                         retrieved[@ext_uniq], 'merged') if merged

        add_history.call(new_pull_req[:id], date(retrieved['closed_at']),
                         retrieved[@ext_uniq], 'closed') if closed
      end

      ensure_pull_request_commits(owner, repo, pullreq_id)
      ensure_pull_request_comments(owner, repo, pullreq_id)

      pulls_reqs.first(:base_repo_id => project[:id],
                       :pullreq_id => pullreq_id)
    end

    def ensure_pull_request_comments(owner, repo, pullreq_id, date_added = nil)

    end

    def ensure_pull_request_commits(owner, repo, pullreq_id)

    end

    private

    # Store a commit contained in a hash. First check whether the commit exists.
    def store_commit(c, repo, user)
      commits = @db[:commits]
      commit = commits.first(:sha => c['sha'])

      if commit.nil?
        author = commit_user(c['author'], c['commit']['author'])
        commiter = commit_user(c['committer'], c['commit']['committer'])

        userid = @db[:users].filter(:login => user).first[:id]
        repoid = @db[:projects].filter(:owner_id => userid,
                                       :name => repo).first[:id]

        commits.insert(:sha => c['sha'],
                       :author_id => author[:id],
                       :committer_id => commiter[:id],
                       :project_id => repoid,
                       :created_at => date(c['commit']['author']['date']),
                       :ext_ref_id => c[@ext_uniq]
        )
        debug "GHTorrent: New commit #{repo} -> #{c['sha']} "
        commits.first(:sha => c['sha'])
      else
        debug "GHTorrent: Commit #{repo} -> #{c['sha']} exists"
        commit
      end
    end

    # Run a block in a DB transaction. Exceptions trigger transaction rollback
    # and are rethrown.
    def transaction(&block)
      start_time = Time.now
      @db.transaction(:rollback => :reraise, :isolation => :committed) do
        yield block
      end
      total = Time.now.to_ms - start_time.to_ms
      debug "GHTorrent: Transaction committed (#{total} ms)"
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
