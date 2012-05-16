module GHTorrent
  module Retriever
    include GHTorrent::Logging
    include GHTorrent::APIClient
    include GHTorrent::Settings

    def retrieve_user_byusername(user)
      stored_user = @persister.retrieve(:users, {'login' => user})
      if stored_user.empty?
        url = config(:mirror_urlbase) + "users/#{user}"
        u = api_request(url)
        @persister.store(:users, u)
        info "New user #{user}"
        u
      else
        debug "Already got #{user}"
        stored_user.first
      end
    end

    # Try Github API v2 user search by email. This is optional info, so
    # it may not return any data.
    # http://develop.github.com/p/users.html
    def retrieve_user_byemail(email, name)
      url = @url_base_v2 + "user/email/#{email}"
      api_request(url)
    end

    def retrieve_user_followers(user)
      stored_followers =  @persister.retrieve(:followers, {'login' => user})

      if stored_followers.empty?
        followers = paged_api_request(config(:mirror_urlbase) + "users/#{user}/followers")
        followers.each {|x|
          x['follows'] = user
          @persister.store(:followers, x)
          info "Added follower #{x['login']} for user #{user}"
        }
      else
        debug "Already got followers for #{user}"
        stored_followers
      end
    end

    def retrieve_commit(repo, sha, user)
      commit = @persister.retrieve(:commits, {'sha' => "#{sha}"})

      if commit.empty?
        url = config(:mirror_urlbase) + "repos/#{user}/#{repo}/commits/#{sha}"
        c = api_request(url)

        @persister.store(:commits, c)
        info "New commit #{sha}"
        c
      else
        debug "Already got #{sha}"
        commit.first
      end
    end

    def retrieve_repo(user, repo)
      stored_repo = @persister.retrieve(:repos, {'owner.login' => user,
                                                 'name' => repo })
      if stored_repo.empty?
        url = config(:mirror_urlbase) + "repos/#{user}/#{repo}"
        r = api_request(url)
        @persister.store(:repos, r)
        info "New repo #{user} -> #{repo}"
        r
      else
        debug "Already got repo #{user} -> #{repo}"
        stored_repo.first
      end
    end

  end
end
