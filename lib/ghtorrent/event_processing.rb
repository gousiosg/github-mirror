module GHTorrent
  module EventProcessing

    def PushEvent(data)
      data['payload']['commits'].each do |c|
        url = c['url'].split(/\//)

        unless url[7].match(/[a-f0-9]{40}$/)
          error "Ignoring commit #{sha}"
          return
        end

        ghtorrent.ensure_commit(url[5], url[7], url[4])
      end
    end

    def WatchEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      watcher = data['actor']['login']
      created_at = data['created_at']

      ghtorrent.ensure_watcher(owner, repo, watcher, created_at)
    end

    def FollowEvent(data)
      follower = data['actor']['login']
      followed = data['payload']['target']['login']
      created_at = data['created_at']

      ghtorrent.ensure_user_follower(followed, follower, created_at)
    end

    def MemberEvent(data)
      owner = data['actor']['login']
      repo = data['repo']['name'].split(/\//)[1]
      new_member = data['payload']['member']['login']
      date_added = data['created_at']

      ghtorrent.transaction do
        pr_members = ghtorrent.get_db[:project_members]
        project = ghtorrent.ensure_repo(owner, repo)
        new_user = ghtorrent.ensure_user(new_member, false, false)

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
              :created_at => ghtorrent.date(added)
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

      ghtorrent.ensure_commit_comment(user, repo, sha, id)
    end

    def PullRequestEvent(data)
      owner = data['payload']['pull_request']['base']['repo']['owner']['login']
      repo = data['payload']['pull_request']['base']['repo']['name']
      pullreq_id = data['payload']['number']
      action = data['payload']['action']
      actor = data['actor']['login']
      created_at = data['created_at']

      ghtorrent.ensure_pull_request(owner, repo, pullreq_id, true, true, true,
                                    action, actor, created_at)
    end

    def ForkEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      fork_id = data['payload']['forkee']['id']

      forkee_owner = data['payload']['forkee']['owner']['login']
      forkee_repo = data['payload']['forkee']['name']

      ghtorrent.ensure_fork(owner, repo, fork_id)
      ghtorrent.ensure_repo_recursive(forkee_owner, forkee_repo, true)
    end

    def PullRequestReviewCommentEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      comment_id = data['payload']['comment']['id']
      pullreq_id = data['payload']['comment']['_links']['pull_request']['href'].split(/\//)[-1]

      ghtorrent.ensure_pullreq_comment(owner, repo, pullreq_id, comment_id)
    end

    def IssuesEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      issue_id = data['payload']['issue']['number']

      ghtorrent.ensure_issue(owner, repo, issue_id)
    end

    def IssueCommentEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      issue_id = data['payload']['issue']['number']
      comment_id = data['payload']['comment']['id']

      ghtorrent.ensure_issue_comment(owner, repo, issue_id, comment_id)
    end

    def CreateEvent(data)
      owner = data['repo']['name'].split(/\//)[0]
      repo = data['repo']['name'].split(/\//)[1]
      return unless data['payload']['ref_type'] == 'repository'

      ghtorrent.ensure_repo(owner, repo)
      ghtorrent.ensure_repo_recursive(owner, repo, false)
    end
  end
end