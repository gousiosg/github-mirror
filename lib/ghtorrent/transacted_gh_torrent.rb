require 'ghtorrent/ghtorrent'

# A version of the GHTorrent class that creates a transaction per processed
# item
class TransactedGHTorrent < GHTorrent::Mirror
  def ensure_repo(owner, repo, recursive = false)
    check_transaction do
      super(owner, repo, recursive)
    end
  end

  def ensure_commit(repo, sha, user, comments = true)
    check_transaction do
      super(repo, sha, user, comments)
    end
  end

  def ensure_commit_comment(owner, repo, sha, comment_id)
    check_transaction do
      super(owner, repo, sha, comment_id)
    end
  end

  def ensure_fork(owner, repo, fork_id)
    check_transaction do
      super(owner, repo, fork_id)
    end
  end

  def ensure_fork_commits(owner, repo, parent_owner, parent_repo)
    check_transaction do
      super(owner, repo, parent_owner, parent_repo)
    end
  end

  def ensure_pull_request(owner, repo, pullreq_id,
                          comments = true, commits = true, history = true,
                          state = nil, actor = nil, created_at = nil)
    check_transaction do
      super(owner, repo, pullreq_id, comments, commits, history, state, actor, created_at)
    end
  end

  def ensure_pullreq_comment(owner, repo, pullreq_id, comment_id, pr_obj = nil)
    check_transaction do
      super(owner, repo, pullreq_id, comment_id, pr_obj)
    end
  end

  def ensure_issue(owner, repo, issue_id, events = true, comments = true, labels = true)
    check_transaction do
      super(owner, repo, issue_id, events, comments, labels)
    end
  end

  def ensure_issue_event(owner, repo, issue_id, event_id)
    check_transaction do
      super(owner, repo, issue_id, event_id)
    end
  end

  def ensure_issue_comment(owner, repo, issue_id, comment_id, pull_req_id = nil)
    check_transaction do
      super(owner, repo, issue_id, comment_id, pull_req_id)
    end
  end

  def ensure_issue_label(owner, repo, issue_id, name)
    check_transaction do
      super(owner, repo, issue_id, name)
    end
  end


  def ensure_watcher(owner, repo, watcher, date_added = nil)
    check_transaction do
      super(owner, repo, watcher, date_added)
    end
  end

  def ensure_repo_label(owner, repo, name)
    check_transaction do
      super(owner, repo, name)
    end
  end

  def ensure_user_followers(user)
    check_transaction do
      super(user)
    end
  end

  def ensure_orgs(user)
    check_transaction do
      super(user)
    end
  end

  def ensure_org(user, members = true)
    check_transaction do
      super(user, members)
    end
  end

  def check_transaction(&block)
    if db.in_transaction?
      yield block
    else
      transaction do
        yield block
      end
    end
  end
end
