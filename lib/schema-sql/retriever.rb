#require File.join(File.dirname(__FILE__), "logging")
#require File.join(File.dirname(__FILE__), "persister")
#require File.join(File.dirname(__FILE__), "api_client")

module GHTorrent
  module Retriever
    include GHTorrent::Logging
    include GHTorrent::Persister
    include GHTorrent::APIClient

    def retrieve_commit(repo, sha, user)
      commit = @persister.retrieve(:commits, {'sha' => "#{sha}"})

      if commit.empty?
        url = @url_base + "repos/#{user}/#{repo}/commits/#{sha}"
        c = api_request(url)

        @persister.store(:commits, c)
        info "New commit #{sha}"
        c
      else
        debug "Already got #{sha}"
        commit.first
      end
    end

    def retrieve_user_byusername(user)
      user = @persister.retrieve(:users, {'login' => "#{user}"})
      if user.empty?
        url = @url_base + "users/#{user}"
        u = api_request(url)
        @persister.store(:user, u)
        info "New user #{user}"
        u
      else
        debug "Mongo: Already got #{user}"
        user.first
      end
    end
  end
end
