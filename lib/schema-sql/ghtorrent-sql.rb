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

require 'sequel'

module GHTorrent
  class GHTorrentSQL

    include GHTorrent::Settings
    include GHTorrent::Logging
    include GHTorrent::Retriever

    attr_reader :settings

    def initialize(configuration)

      @settings = YAML::load_file configuration
      super(@settings)
      @ext_uniq = config(:uniq_id)
      @logger = Logger.new(STDOUT)
      @persister = Persister.new(:mongo, @settings)
      get_db
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
        error "GHTorrent: Ignoring commit #{sha}"
        return
      end

      commits = @db[:commits]
      commit = commits.first(:sha => sha)

      if commit.nil?
        @db.transaction(:rollback => :reraise) do
          ensure_repo(user, repo)
          c = retrieve_commit(repo, sha, user)

          author = commit_user(c['author'], c['commit']['author'])
          commiter = commit_user(c['committer'], c['commit']['committer'])

          commits.insert(:sha => sha,
                         :author_id => author[:id],
                         :committer_id => commiter[:id],
                         :created_at => date(c['commit']['author']['date']),
                         :ext_ref_id => c[@ext_uniq]
          )

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
        end
        debug "GHTorrent: Transaction committed"
      else
        debug "GHTorrent: Commit #{sha} exists"
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
      email = commituser['email'] #if is_valid_email(commituser['email'])
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
      # Github only supports alpa-nums and dashes in its usernames.
      # All other sympbols are treated as emails.
      u = if not user.match(/^[A-Za-z0-9\-]*$/)
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
                     :created_at => date(u['created_at']),
                     :ext_ref_id => u[@ext_uniq])

        info "GHTorrent: New user #{user}"

        # Get the user's followers
        ensure_user_followers(user) if followers

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
    def ensure_user_followers(user, ts = Time.now)

      followers = retrieve_new_user_followers(user)
      followers.each { |f|
        follower = f['login']
        ensure_user(user, false)
        ensure_user(follower, false)

        userid = @db[:users].select(:id).first(:login => user)[:id]
        followerid = @db[:users].select(:id).first(:login => follower)[:id]
        followers = @db[:followers]

        if followers.first(:user_id => userid, :follower_id => followerid).nil?
          @db[:followers].insert(:user_id => userid,
                                 :follower_id => followerid,
                                 :created_at => ts,
                                 :ext_ref_id => f[@ext_uniq]
          )
          info "GHTorrent: User #{follower} follows #{user}"
        else
          info "User #{follower} already follows #{user}"
        end
      }
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

        u = retrieve_user_byemail(email, name)

        if u.nil? or u['user'].nil? or u['user']['login'].nil?
          debug "GHTorrent: Cannot find #{email} through API v2 query"
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
          debug "GHTorrent: Found #{email} through API v2 query"
          ensure_user_followers(user) if followers
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
    # == Returns: If the repo can be retrieved, it is returned as a Hash.
    #             Otherwise, the result is nil
    def ensure_repo(user, repo)

      ensure_user(user, false)
      repos = @db[:projects]
      currepo = repos.first(:name => repo)

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
        repos.first(:name => repo)
      else
        debug "GHTorrent: Repo #{repo} exists"
        currepo
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

    def is_valid_email(email)
      email =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
    end
  end
  # Base exception for all GHTorrent exceptions
  class GHTorrentException < Exception

  end

end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
