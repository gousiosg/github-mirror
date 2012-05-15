# Copyright 2012 Georgios Gousios <gousiosg@gmail.com>
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#   1. Redistributions of source code must retain the above
#      copyright notice, this list of conditions and the following
#      disclaimer.
#
#   2. Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials
#      provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

#require 'rubygems'
require 'sequel'

module GHTorrent
  class GHTorrentSQL

    include GHTorrent::Settings
    include GHTorrent::Logging
    include GHTorrent::Retriever

    attr_reader :settings
    attr_reader :log
    attr_reader :num_api_calls

    def init(config)
      @settings = YAML::load_file config
      @ts = Time.now().tv_sec()
      @num_api_calls = 0
      @log = Logger.new(STDOUT)
      get_db
      get_mongo
      @url_base = @settings['mirror']['urlbase']
      @url_base_v2 = @settings['mirror']['urlbase_v2']
    end

    # db related functions
    def get_db

      @db = Sequel.connect('sqlite://github.db')
      #@db.loggers << @log
      if @db.tables.empty?
        dir = File.join(File.dirname(__FILE__), 'migrations')
        puts("Database empty, running migrations from #{dir}")
        Sequel.extension :migration
        Sequel::Migrator.apply(@db, dir)
      end
      @db
    end


    ##
    # Ensure that a user exists, or fetch its latest state from Github
    # ==Parameters:
    #  user::
    #     The email or login name to lookup the user by
    #
    # == Returns:
    # If the user can be retrieved, it is returned as a Hash. Otherwise,
    # the result is nil
    def get_commit(user, repo, sha)

      unless sha.match(/[a-f0-9]{40}$/)
        @log.error "Ignoring commit #{sha}"
        return
      end

      commits = @db[:commits]
      commit = commits.first(:sha => sha)

      if commit.nil?
        @db.transaction do
          ensure_repo(user, repo)
          c = retrieve_commit(repo, sha, user)

          author = commit_user(c['author'], c['commit']['author'])
          commiter = commit_user(c['committer'], c['commit']['committer'])

          commits.insert(:sha => sha,
                         :author_id => author[:id],
                         :committer_id => commiter[:id],
                         :created_at => date(c['commit']['author']['date']))

          #c['parents'].each do |p|
          #  url = p['url'].split(/\//)
          #  get_commit url[4], url[5], url[7]
          #
          #  commit = commits.first(:sha => sha)
          #  parent = commits.first(:sha => url[7])
          #  @db[:commit_parents].insert(:commit_id => commit[:id],
          #                              :parent_id => parent[:id])
          #  @log.info "Added parent #{parent[:sha]} to commit #{sha}"
          #end

          @log.debug("Transaction committed")
        end
      else
        @log.debug "Commit #{sha} exists"
      end
    end

    ##
    # Add (or update) an entry for a commit author. This method uses information
    # in the JSON object returned by Github to add (or update) a user in the
    # metadata database with a full user entry (both Git and Github details).
    # Resolution of how
    #
    # ==Parameters:
    #  githubuser::
    #     A hash containing the user's Github login
    #  commituser::
    #     A hash containing the Git commit's user name and email
    # == Returns:
    # The (added/modified) user entry as a Hash.
    def commit_user(githubuser, commituser)

      raise GHTorrentException.new "git user is null" if commituser.nil?

      users = @db[:users]

      name = commituser['name']
      email = commituser['email']
      # Github user can be null when the commit email has not been associated
      # with any account in Github.
      login = githubuser['login'] unless githubuser.nil?

      if login.nil?
        ensure_user("#{name}<#{email}>", true)
      else
        dbuser = users.first(:login => login)
        byemail = users.first(:email => email)
        if dbuser.nil?
          # We do not have the user in the database yet. Add him
          added = ensure_user(login, true)
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
                :bio => added['bio'],
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
    #  user::
    #     The full email address in RFC 822 format
    #     or a login name to lookup the user by
    #  followers::
    #     A boolean value indicating whether to retrieve the user's followers
    # == Returns:
    # If the user can be retrieved, it is returned as a Hash. Otherwise,
    # the result is nil
    def ensure_user(user, followers)
      u = if user.match(/@/)
            begin
              name, email = user.split("<")
              email = email.split(">")[0]
            rescue Exception
              raise new GHTorrentException("Not a valid email address: #{user}")
            end
            ensure_user_byemail(email.strip, name.strip, followers)
          else
            ensure_user_byuname(user, followers)
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
    def ensure_user_byuname(user, followers)
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

        users.insert(:login => u['login'],
                     :name => u['name'],
                     :company => u['company'],
                     :email => email,
                     :hireable => boolean(u['hirable']),
                     :bio => u['bio'],
                     :location => u['location'],
                     :created_at => date(u['created_at']))

        @log.info "New user #{user}"

        # Get the user's followers
        ensure_user_followers(user) if followers

        users.first(:login => user)
      else
        @log.debug "User #{user} exists"
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
    def ensure_user_followers(user)

      followers = paged_api_request(@url_base + "users/#{user}/followers")
      ts = Time.now
      followers.each { |f| ensure_follower(user, f['login'], ts) }
    end

    ##
    # Get a single follower for a user.
    #
    # ==Parameters:
    # [user]  The user login who is being followed
    # [follower]  The user login of the follower
    # [ts]  The +Time+ the follow event took place
    def ensure_follower(user, follower, ts)

      ensure_user(user, false)
      ensure_user(follower, false)

      userid = @db[:users].select(:id).first(:login => user)[:id]
      followerid = @db[:users].select(:id).first(:login => follower)[:id]
      followers = @db[:followers]

      if followers.first(:user_id => userid, :follower_id => followerid).nil?
        @db[:followers].insert(:user_id => userid,
                               :follower_id => followerid,
                               :created_at => ts
        )
        log.info("User #{follower} follows #{user}")
      else
        log.info("User #{follower} already follows #{user}")
      end
    end

    ##
    # Try to retrieve a user by email. Search the DB first, fall back to
    # Github API v2 if unsuccessful.
    #
    # ==Parameters:
    #  user::
    #     The email to lookup the user by
    #
    # == Returns:
    # If the user can be retrieved, it is returned as a Hash. Otherwise,
    # the result is nil
    def ensure_user_byemail(email, name, followers)
      users = @db[:users]
      usr = users.first(:email => email)

      if usr.nil?
        # Try Github API v2 user search by email. This is optional info, so
        # it may not return any data.
        # http://develop.github.com/p/users.html
        url = @url_base_v2 + "user/email/#{email}"
        u = api_request(url)

        if u['user'].nil? or u['user']['login'].nil?
          @log.debug "Cannot find #{email} through API v2 query"
          users.insert(:email => email,
                       :name => name,
                       :login => (0...8).map { 65.+(rand(25)).chr }.join,
                       :created_at => Time.now
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
                       :created_at => date(u['user']['created_at']))
          @log.debug "Found #{email} through API v2 query"
          ensure_user_followers(user) if followers
          users.first(:email => email)
        end
      else
        @log.debug "User with email #{email} exists"
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
    # == Returns: If the repo can be retrieved, it is returned as a Hash.
    #             Otherwise, the result is nil
    def ensure_repo(user, repo)

      ensure_user(user, false)
      repos = @db[:projects]
      currepo = repos.first(:name => repo)

      if currepo.nil?
        url = @url_base + "repos/#{user}/#{repo}"
        r = api_request(url)

        repos.insert(:url => r['url'],
                     :owner_id => @db[:users].filter(:login => user).first[:id],
                     :name => r['name'],
                     :description => r['description'],
                     :language => r['language'],
                     :created_at => date(r['created_at']))

        @log.info "New repo #{repo}"
        repos.first(:name => repo)
      else
        @log.debug "Repo #{repo} exists"
        currepo
      end
    end

    ##
    # Get current Github events
    def get_events
      api_request "https://api.github.com/events"
    end

    # Read a value whose format is "foo.bar.baz" from a hierarchical map
    # (the result of a JSON parse or a Mongo query), where a dot represents
    # one level deep in the result hierarchy.
    def read_value(from, key)
      return from if key.nil? or key == ""

      key.split(/\./).reduce({}) do |acc, x|
        unless acc.nil?
          if acc.empty?
            # Initial run
            acc = from[x]
          else
            if acc.has_key?(x)
              acc = acc[x]
            else
              # Some intermediate key does not exist
              return ""
            end
          end
        else
          # Some intermediate key returned a null value
          # This indicates a malformed entry
          return ""
        end
      end
    end

    private

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
      Time.parse(arg).to_i
    end

  end

  # Base exception for all GHTorrent exceptions
  class GHTorrentException < Exception

  end

end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
