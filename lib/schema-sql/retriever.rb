module GHTorrent
  module Retriever

    include GHTorrent::APIClient

    def retrieve_user_byusername(user)
      stored_user = @persister.retrieve(:users, {'login' => user})
      if stored_user.empty?
        url = ghurl "users/#{user}"
        u = api_request(url)
        @persister.store(:users, u)
        info "Retriever: New user #{user}"
        u
      else
        debug "Retriever: Already got #{user}"
        stored_user.first
      end
    end

    # Try Github API v2 user search by email. This is optional info, so
    # it may not return any data.
    # http://develop.github.com/p/users.html
    def retrieve_user_byemail(email, name)
      url = ghurl_v2("user/email/#{email}")
      api_request(url)
    end

    def retrieve_user_followers(user)
      stored_followers =  @persister.retrieve(:followers, {'login' => user})

      if stored_followers.empty?
        followers = paged_api_request(ghurl "users/#{user}/followers")
        followers.each {|x|
          x['follows'] = user
          @persister.store(:followers, x)
          info "Retriever: Added follower #{x['login']} for user #{user}"
        }
      else
        debug "Retriever: Already got followers for #{user}"
        stored_followers
      end
    end

    def retrieve_commit(repo, sha, user)
      commit = @persister.retrieve(:commits, {'sha' => "#{sha}"})

      if commit.empty?
        url = ghurl "repos/#{user}/#{repo}/commits/#{sha}"
        c = api_request(url)

        @persister.store(:commits, c)
        info "Retriever: New commit #{sha}"
        c
      else
        debug "Retriever: Already got #{sha}"
        commit.first
      end
    end

    def retrieve_repo(user, repo)
      stored_repo = @persister.retrieve(:repos, {'owner.login' => user,
                                                 'name' => repo })
      if stored_repo.empty?
        url = ghurl "repos/#{user}/#{repo}"
        r = api_request(url)
        @persister.store(:repos, r)
        info "Retriever: New repo #{user} -> #{repo}"
        r
      else
        debug "Retriever: Already got repo #{user} -> #{repo}"
        stored_repo.first
      end
    end

    private

    def ghurl(path)
      config(:mirror_urlbase) + path
    end

    def ghurl_v2(path)
      config(:mirror_urlbase_v2) + path
    end
  end
end
