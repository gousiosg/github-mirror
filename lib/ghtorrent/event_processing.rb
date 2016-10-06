module GHTorrent
  module EventProcessing

    include GHTorrent::Retriever

    def persister
      raise 'Unimplemented'
    end

    def ght
      raise 'Unimplemented'
    end

    def PushEvent(data)
      data['payload']['commits'].each do |c|
        url = c['url'].split(/\//)

        unless url[7].match(/[a-f0-9]{40}$/)
          error "Ignoring commit #{sha}"
          return
        end

        ght.ensure_commit(url[5], url[7], url[4])
      end

      # Take care of pushes with more than 20 commits
      # Retrieve commits after the until we find one that is registered with the current repo
      if data['payload']['commits'].size >= 20
        info "PushEvent #{data['id']} has >= 20 commits."

        owner        = data['repo']['name'].split(/\//)[0]
        repo         = data['repo']['name'].split(/\//)[1]
        last_sha     = data['payload']['commits'].last['url'].split(/\//)[7]
        push_commits = data['payload']['commits'].map { |x| x['sha'] }

        attempts = 0
        while true
          attempts += 1
          commits = retrieve_commits(repo, last_sha, owner, 1)
          return if attempts > 1 and commits[0]['sha'] == last_sha

          commits.each do |c|
            url = c['url'].split(/\//)
            next if push_commits.include? url[7]

            sha_not_exist = ght.db.from(:commits, :project_commits, :projects, :users).\
                            where(:projects__id => :project_commits__project_id).\
                            where(:commits__id => :project_commits__commit_id).\
                            where(:projects__owner_id => :users__id).\
                            where(:projects__name => url[5]).\
                            where(:users__login => url[4]).\
                            where(:commits__sha => url[7]).all.empty?

            if not sha_not_exist
              debug "Commit #{url[7]} already registered with #{url[4]}/#{url[5]}."
              return
            end

            ght.ensure_commit(url[5], url[7], url[4])
            last_sha = url[7]
          end
        end
      end

    end

    def WatchEvent(e)
      owner      = e['repo']['name'].split(/\//)[0]
      repo       = e['repo']['name'].split(/\//)[1]
      watcher    = e['actor']['login']
      created_at = e['created_at']

      watcher_db = ght.ensure_user(watcher, false, false)

      watcher_entry = {
          'login'               => watcher,
          'id'                  => e['actor']['id'],
          'avatar_url'          => e['actor']['avatar_url'],
          'gravatar_id'         => e['actor']['gravatar_id'],
          'url'                 => e['actor']['url'],
          'html_url'            => "https://github.com/#{watcher}",
          'followers_url'       => "https://api.github.com/users/#{watcher}/followers",
          'following_url'       => "https://api.github.com/users/#{watcher}/following{/other_user}",
          'gists_url'           => "https://api.github.com/users/#{watcher}/gists{/gist_id}",
          'starred_url'         => "https://api.github.com/users/#{watcher}/starred{/owner}{/repo}",
          'subscriptions_url'   => "https://api.github.com/users/#{watcher}/subscriptions",
          'organizations_url'   => "https://api.github.com/users/#{watcher}/orgs",
          'repos_url'           => "https://api.github.com/users/#{watcher}/repos",
          'events_url'          => "https://api.github.com/users/#{watcher}/events{/privacy}",
          'received_events_url' => "https://api.github.com/users/#{watcher}/received_events",
          'type'                => watcher_db[:type],
          'site_admin'          => false,
          'created_at'          => created_at,
          'owner'               => owner,
          'repo'                => repo
      }

      persister.upsert(:watchers, {'owner' => owner, 'repo' => repo, 'login' => watcher}, watcher_entry)
      ght.ensure_watcher(owner, repo, watcher, created_at)
    end

    def FollowEvent(data)
      follower = data['actor']['login']
      followed = data['payload']['target']['login']
      created_at = data['created_at']

      ght.ensure_user_follower(followed, follower, created_at)
    end

    def MemberEvent(data)
      owner = data['actor']['login']
      repo = data['repo']['name'].split(/\//)[1]
      new_member = data['payload']['member']['login']
      date_added = data['created_at']

      ght.transaction do
        pr_members = ght.db[:project_members]
        project = ght.ensure_repo(owner, repo)
        new_user = ght.ensure_user(new_member, false, false)

        if project.nil? or new_user.nil?
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

          pr_members.insert(
              :user_id => new_user[:id],
              :repo_id => project[:id],
              :created_at => ght.date(added)
          )
          info "Added project member #{repo} -> #{new_member}"
        else
          debug "Project member #{repo} -> #{new_member} exists"
        end
      end

    end

    def CommitCommentEvent(data)
      user = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      id = data['payload']['comment']['id']
      sha = data['payload']['comment']['commit_id']

      ght.ensure_commit_comment(user, repo, sha, id)
    end

    def PullRequestEvent(data)
      owner = data['payload']['pull_request']['base']['repo']['owner']['login']
      repo = data['payload']['pull_request']['base']['repo']['name']
      pullreq_id = data['payload']['number']
      action = data['payload']['action']
      actor = data['actor']['login']
      created_at = data['created_at']

      pr = data['payload']['pull_request']
      pr['owner'] = owner
      pr['repo'] = repo

      persister.upsert(:pull_requests,
                       {'owner' => owner, 'repo' => repo, 'number' => pullreq_id},
                       pr)

      ght.ensure_pull_request(owner, repo, pullreq_id, true, true, true,
                                    action, actor, created_at)
    end

    def ForkEvent(data)
      owner   = data['repo']['name'].split(/\//)[0]
      repo    = data['repo']['name'].split(/\//)[1]
      fork_id = data['payload']['forkee']['id']

      forkee = data['payload']['forkee']
      forkee['owner'] = owner
      forkee['repo'] = repo

      persister.upsert(:forks,
                       {'owner' => owner, 'repo' => repo, 'id' => fork_id},
                       forkee)

      ght.ensure_fork(owner, repo, fork_id)
    end

    def PullRequestReviewCommentEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      comment_id = data['payload']['comment']['id']
      pullreq_id = data['payload']['comment']['_links']['pull_request']['href'].split(/\//)[-1]

      ght.ensure_pullreq_comment(owner, repo, pullreq_id, comment_id)
    end

    def IssuesEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      issue_id = data['payload']['issue']['number']

      ght.ensure_issue(owner, repo, issue_id)
    end

    def IssueCommentEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      issue_id = data['payload']['issue']['number']
      comment_id = data['payload']['comment']['id']

      ght.ensure_issue_comment(owner, repo, issue_id, comment_id)
    end

    def CreateEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      return unless data['payload']['ref_type'] == 'repository'

      ght.ensure_repo(owner, repo)
      ght.ensure_repo_recursive(owner, repo, false)
    end
  end
end
