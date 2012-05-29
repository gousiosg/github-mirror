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
# AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
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

module GHTorrent
  module Retriever

    include GHTorrent::APIClient
    include GHTorrent::Settings

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
        info "Retriever: New user #{user}"
        u
      else
        debug "Retriever: Already got user #{user}"
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

    def retrieve_new_user_followers(user)
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
  end
end
