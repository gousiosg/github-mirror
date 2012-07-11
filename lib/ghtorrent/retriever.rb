module GHTorrent
  module Retriever

    include GHTorrent::Utils
    include GHTorrent::APIClient

    def initialize(settings)
      super(settings)
      @settings = settings
      @uniq = config(:uniq_id)
    end

    def retrieve_user_byusername(user)
      stored_user = @persister.find(:users, {'login' => user})
      if stored_user.empty?
        url = ghurl "users/#{user}"
        u = api_request(url)

        if u.empty?
          throw GHTorrentException.new("Cannot find user #{user}")
        end

        unq = @persister.store(:users, u)
        u[@uniq] = unq
        what = user_type(u['type'])
        info "Retriever: New #{what} #{user}"
        u
      else
        what = user_type(stored_user.first['type'])
        debug "Retriever: Already got #{what} #{user}"
        stored_user.first
      end
    end

    # Try Github API v2 user search by email. This is optional info, so
    # it may not return any data.
    # http://develop.github.com/p/users.html
    def retrieve_user_byemail(email, name)
      url = ghurl_v2("user/email/#{email}")
      r = api_request(url)

      return nil if r.empty?
      r
    end

    def retrieve_user_followers(user)
      stored_followers = @persister.find(:followers, {'follows' => user})

      followers = paged_api_request(ghurl "users/#{user}/followers")
      followers.each do |x|
        x['follows'] = user

        exists = !stored_followers.find { |f|
          f['follows'] == user && f['login'] == x['login']
        }.nil?

        if not exists
          @persister.store(:followers, x)
          info "Retriever: Added follower #{user} -> #{x['login']}"
        else
          debug "Retriever: Follower #{user} -> #{x['login']} exists"
        end
      end

      @persister.find(:followers, {'follows' => user})
    end

    # Retrieve a single commit from a repo
    def retrieve_commit(repo, sha, user)
      commit = @persister.find(:commits, {'sha' => "#{sha}"})

      if commit.empty?
        url = ghurl "repos/#{user}/#{repo}/commits/#{sha}"
        c = api_request(url)

        if c.empty?
          throw GHTorrentException.new("Cannot find commit #{user}/#{repo}/#{sha}")
        end

        unq = @persister.store(:commits, c)
        info "Retriever: New commit #{repo} -> #{sha}"
        c[@uniq] = unq
        c
      else
        debug "Retriever: Already got commit #{repo} -> #{sha}"
        commit.first
      end
    end

    # Retrieve all project commits or 500 (whatever comes first),
    # starting from the provided +sha+
    def retrieve_commits(repo, sha, user)
      last_sha = if sha.nil?
                  "master"
                 else
                  sha
                 end

      url = ghurl "repos/#{user}/#{repo}/commits?last_sha=#{last_sha}"
      commits = paged_api_request(url, config(:mirror_commit_pages_new_repo))

      commits.reduce(Array.new) do |acc, c|
        commit = @persister.find(:commits, {'sha' => "#{c['sha']}"})

        if commit.empty?
          acc << retrieve_commit(repo, c['sha'], user)
        else
          debug "Retriever: Already got commit #{repo} -> #{c['sha']}"
        end
        acc
      end
    end


    def retrieve_repo(user, repo)
      stored_repo = @persister.find(:repos, {'owner.login' => user,
                                             'name' => repo })
      if stored_repo.empty?
        url = ghurl "repos/#{user}/#{repo}"
        r = api_request(url)

        if r.empty?
          throw GHTorrentException.new("Cannot find repo #{user}/#{repo}")
        end

        unq = @persister.store(:repos, r)
        info "Retriever: New repo #{user} -> #{repo}"
        r[@uniq] = unq
        r
      else
        debug "Retriever: Already got repo #{user} -> #{repo}"
        stored_repo.first
      end
    end

    # Retrieve organizations the provided user participates into
    def retrieve_orgs(user)
      url = ghurl "users/#{user}/orgs"
      orgs = paged_api_request(url)
      orgs.map{|o| retrieve_org(o['login'])}
    end

    # Retrieve a single organization
    def retrieve_org(org)
      retrieve_user_byusername(org)
    end

    # Retrieve organization members
    def retrieve_org_members(org)
      url = ghurl "orgs/#{org}/members"
      stored_org_members = @persister.find(:org_members, {'org' => org})

      org_members = paged_api_request(ghurl "orgs/#{org}/members")
      org_members.each do |x|
        x['org'] = org

        exists = !stored_org_members.find { |f|
          f['org'] == user && f['login'] == x['login']
        }.nil?

        if not exists
          @persister.store(:org_members, x)
          info "Retriever: Added member #{org} -> #{x['login']}"
        else
          debug "Retriever: Member #{org} -> #{x['login']} exists"
        end
      end

      @persister.find(:org_members, {'org' => org}).map{|o| retrieve_org(o['login'])}
    end

    # Retrieve all commit comments for a specific repository
    def retrieve_repo_comments(repo, user)
      commit_comments = paged_api_request(ghurl "repos/#{user}/#{repo}/comments")
      stored_comments = @persister.find(:commit_comments,
                                        {'repo' => repo,
                                         'user' => user})
      store_commit_comments(repo, user, commit_comments, stored_comments)
    end

    # Retrieve all comments for a single commit
    def retrieve_commit_comments(user, repo, sha, reentrer = false)
      # Optimization: if no commits comments are registered for the repo
      # get them en masse
      #items = @persister.count(:commit_comments, {'repo' => repo, 'user' => user})
      #if items == 0 && !reentrer
      #  retrieve_repo_comments(repo, user)
      #  return retrieve_commit_comments(user, repo, sha, true)
      #end

      stored_comments = @persister.find(:commit_comments, {'commit_id' => sha})
      retrieved_comments = paged_api_request(ghurl "repos/#{user}/#{repo}/commits/#{sha}/comments")
      store_commit_comments(repo, user, stored_comments, retrieved_comments)
      @persister.find(:commit_comments, {'commit_id' => sha})
    end

    # Retrieve a single comment
    def retrieve_commit_comment(user, repo, id, reentrer = false)
      # Optimization: if no commits comments are registered for the repo
      # get them en masse
      #items = @persister.count(:commit_comments, {'repo' => repo, 'user' => user})
      #if items == 0 && !reentrer
      #  retrieve_repo_comments(repo, user)
      #  return retrieve_commit_comment(user, repo, id)
      #end

      comment = @persister.find(:commit_comments, {'repo' => repo,
                                                   'user' => user, 'id' => id})
      if comment.empty?
        r = api_request(ghurl "repos/#{user}/#{repo}/comments/#{id}")
        r['repo'] = repo
        r['user'] = user
        @persister.store(:commit_comments, r)
        info "Retriever: Added commit comment #{r['commit_id']} -> #{r['id']}"
        r[@uniq] = r['_id']
        r
      else
        debug "Retriever: Commit comment #{comment['commit_id']} -> #{comment['id']} exists"
        comment[@uniq] = comment['_id']
        comment
      end
    end

    # Get current Github events
    def get_events
      api_request "https://api.github.com/events"
    end

    private

    def ghurl(path)
      config(:mirror_urlbase) + path
    end

    def ghurl_v2(path)
      config(:mirror_urlbase_v2) + path
    end

    def store_commit_comments(repo, user, stored_comments, retrieved_comments)
      retrieved_comments.each do |x|

        exists = !stored_comments.find { |f|
          f['commit_id'] == x['commit_id'] && f['id'] == x['id']
        }.nil?

        unless exists
          x['repo'] = repo
          x['user'] = user

          @persister.store(:commit_comments, x)
          info "Retriever: Added commit comment #{x['commit_id']} -> #{x['id']}"
        else
          debug "Retriever: Commit comment #{x['commit_id']} -> #{x['id']} exists"
        end
      end
    end
  end
end
