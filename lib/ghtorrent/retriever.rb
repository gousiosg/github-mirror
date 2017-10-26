require 'uri'
require 'cgi'

require 'ghtorrent/api_client'
require 'ghtorrent/settings'
require 'ghtorrent/utils'
require 'ghtorrent/logging'

module GHTorrent
  module Retriever

    include GHTorrent::Settings
    include GHTorrent::Utils
    include GHTorrent::APIClient
    include GHTorrent::Logging

    def persister
      raise Exception.new("Unimplemented")
    end

    def retrieve_user_byusername(user)
      stored_user = persister.find(:users, {'login' => user})
      if stored_user.empty?
        url = ghurl "users/#{user}"
        u = api_request(url)

        if u.nil? or u.empty?
          return
        end

        unq = persister.store(:users, u)
        what = user_type(u['type'])
        info "Added user #{what} #{user}"
        u
      else
        what = user_type(stored_user.first['type'])
        debug "#{what} #{user} exists"
        stored_user.first
      end
    end

    # Try Github user search by email. This is optional info, so
    # it may not return any data. If this fails, try searching by name
    # http://developer.github.com/v3/search/#email-search
    def retrieve_user_byemail(email, name)
      url = ghurl("legacy/user/email/#{CGI.escape(email)}")
      byemail = api_request(url)

      if byemail.nil? or byemail.empty?
        # Only search by name if name param looks like a proper name
        byname = if not name.nil? and name.split(/ /).size > 1
                  url = ghurl("legacy/user/search/#{CGI.escape(name)}")
                  api_request(url)
                 end

        if byname.nil? or byname['users'].nil? or byname['users'].empty?
          nil
        else
          user = byname['users'].find do |u|
                u['name'] == name and
                not u['login'].nil? and
                not retrieve_user_byusername(u['login']).nil?
          end

          unless user.nil?
            # Make extra sure that if we got an email it matches that
            # of the retrieved user
            if not email.nil? and user['email'] == email
              user
            else
              warn "Could not find user #{email}"
              nil
            end
          else
            warn "Could not find user #{email}"
            nil
          end
        end
      else
        unless byemail['user']['login'].nil?
          info "Added user #{byemail['user']['login']} retrieved by email #{email}"
          retrieve_user_byusername(byemail['user']['login'])
        else
          u = byemail['user']
          unq = persister.store(:users, u)
          what = user_type(u['type'])
          info "Added user #{what} #{user}"
          u
        end
      end
    end

    def retrieve_user_follower(followed, follower)
      stored_item = persister.find(:followers, {'follows' => followed,
                                                'login' => follower})

      if stored_item.empty?
        retrieve_user_followers(followed).find{|x| x['login'] == follower}
      else
        stored_item.first
      end
    end

    def retrieve_user_followers(user)
      followers = paged_api_request(ghurl "users/#{user}/followers")
      followers.each do |x|
        x['follows'] = user

        exists = !persister.find(:followers, {'follows' => user,
                                              'login' => x['login']}).empty?

        if not exists
          persister.store(:followers, x)
          info "Added follower #{user} -> #{x['login']}"
        else
          debug "Follower #{user} -> #{x['login']} exists"
        end
      end

      persister.find(:followers, {'follows' => user})
    end

    def retrieve_user_following(user)
      following = paged_api_request(ghurl "users/#{user}/following")
      user_followers_entry = nil

      following.each do |x|

        if user_followers_entry.nil?
          reverse_lookup = persister.find(:followers, {'follows' => x['login'],
                                                       'login' => user})
          if reverse_lookup.empty?
            user_followers_entry = retrieve_user_followers(x['login']).\
                                     find{|y| y['login'] == user}
          else
            user_followers_entry = reverse_lookup[0]
          end
        end

        exists = !persister.find(:followers, {'follows' => x['login'],
                                              'login' => user}).empty?
        if not exists
          user_followers_entry['follows'] = x['login']
          user_followers_entry.delete(:_id)
          user_followers_entry.delete('_id')
          a = persister.store(:followers, user_followers_entry)
          info "Added following #{user} -> #{x['login']}"
        else
          debug "Following #{user} -> #{x['login']} exists"
        end
      end

      persister.find(:followers, {'login' => user})
    end

    def retrieve_pull_request_commit(pr_obj, repo, sha, user)
      pull_commit = persister.find(:pull_request_commits, {'sha' => "#{sha}"})

      if pull_commit.empty?
        commit = retrieve_commit(repo, sha, user)

        unless commit.nil?
          commit.delete(nil)
          commit.delete(:_id)
          commit.delete('_id')
          commit['pull_request_id'] = pr_obj[:id]
          persister.store(:pull_request_commits, commit)
          info "Added commit #{user}/#{repo} -> #{sha} with pull_id #{pr_obj['id']}"
          commit
        else
          return
        end
      else
        debug "Pull request commit #{user}/#{repo} -> #{sha} exists for pull id #{pr_obj['id']}"
        pull_commit.first
      end
    end

    # Retrieve a single commit from a repo
    def retrieve_commit(repo, sha, user)
      commit = persister.find(:commits, {'sha' => "#{sha}"})

      if commit.empty?
        url = ghurl "repos/#{user}/#{repo}/commits/#{sha}"
        c = api_request(url)

        if c.nil? or c.empty?
          return
        end

        # commit patches are big and not always interesting
        if config(:commit_handling) == 'trim'
          c['files'].each { |file| file.delete('patch') }
        end
        persister.store(:commits, c)
        info "Added commit #{user}/#{repo} -> #{sha}"
        c
      else
        debug "Commit #{user}/#{repo} -> #{sha} exists"
        commit.first
      end
    end

    # Retrieve commits starting from the provided +sha+
    def retrieve_commits(repo, sha, user, pages = -1)

      url = if sha.nil?
              ghurl "repos/#{user}/#{repo}/commits"
            else
              ghurl "repos/#{user}/#{repo}/commits?sha=#{sha}"
            end

      commits = restricted_page_request(url, pages)

      commits.map do |c|
        retrieve_commit(repo, c['sha'], user)
      end.select{|x| not x.nil?}
    end

    def retrieve_repo(user, repo, refresh = false)
      stored_repo = persister.find(:repos, {'owner.login' => user,
                                             'name' => repo })
      if stored_repo.empty? or refresh
        url = ghurl "repos/#{user}/#{repo}"
        r = api_request(url)

        if r.nil? or r.empty?
          return
        end

        if refresh
          persister.upsert(:repos, {'name' => r['name'], 'owner.login' => r['owner']['login']}, r)
        else
          persister.store(:repos, r)
          info "Added repo #{user} -> #{repo}"
        end
        r
      else
        debug "Repo #{user} -> #{repo} exists"
        stored_repo.first
      end
    end

    def retrieve_languages(owner, repo)
      paged_api_request ghurl "repos/#{owner}/#{repo}/languages"
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
      stored_org_members = persister.find(:org_members, {'org' => org})

      org_members = paged_api_request(ghurl "orgs/#{org}/members")
      org_members.each do |x|
        x['org'] = org

        exists = !stored_org_members.find { |f|
          f['org'] == org && f['login'] == x['login']
        }.nil?

        if not exists
          persister.store(:org_members, x)
          info "Added org_member #{org} -> #{x['login']}"
        else
          debug "Org Member #{org} -> #{x['login']} exists"
        end
      end

      persister.find(:org_members, {'org' => org}).map{|o| retrieve_org(o['login'])}
    end

    # Retrieve all comments for a single commit
    def retrieve_commit_comments(owner, repo, sha)
      retrieved_comments = paged_api_request(ghurl "repos/#{owner}/#{repo}/commits/#{sha}/comments")

      retrieved_comments.each { |x|
        if persister.find(:commit_comments, { 'commit_id' => x['commit_id'],
                                              'id' => x['id']}).empty?
          persister.store(:commit_comments, x)
        end
      }
      persister.find(:commit_comments, {'commit_id' => sha})
    end

    # Retrieve a single comment
    def retrieve_commit_comment(owner, repo, sha, id)

      comment = persister.find(:commit_comments, {'commit_id' => sha,
                                                  'id' => id}).first
      if comment.nil?
        r = api_request(ghurl "repos/#{owner}/#{repo}/comments/#{id}")

        if r.nil? or r.empty?
          warn "Could not find commit_comment #{id}. Deleted?"
          return
        end

        persister.store(:commit_comments, r)
        info "Added commit_comment #{r['commit_id']} -> #{r['id']}"
        persister.find(:commit_comments, {'commit_id' => sha, 'id' => id}).first
      else
        debug "Commit comment #{comment['commit_id']} -> #{comment['id']} exists"
        comment
      end
    end

    # Retrieve all watchers for a repository
    def retrieve_watchers(user, repo)
      repo_bound_items(user, repo, :watchers,
                       ["repos/#{user}/#{repo}/stargazers"],
                       {'repo' => repo, 'owner' => user},
                       'login', item = nil, refresh = false, order = :desc)
    end

    # Retrieve a single watcher for a repository
    def retrieve_watcher(user, repo, watcher)
      repo_bound_item(user, repo, watcher, :watchers,
                      ["repos/#{user}/#{repo}/stargazers"],
                      {'repo' => repo, 'owner' => user},
                      'login', order = :desc)
    end

    def retrieve_pull_requests(user, repo, refr = false)
      open = "repos/#{user}/#{repo}/pulls"
      closed = "repos/#{user}/#{repo}/pulls?state=closed"
      repo_bound_items(user, repo, :pull_requests,
                       [open, closed],
                       {'repo' => repo, 'owner' => user},
                       'number', item = nil, refresh = refr, order = :asc)
    end

    def retrieve_pull_request(user, repo, pullreq_id)
      open = "repos/#{user}/#{repo}/pulls"
      closed = "repos/#{user}/#{repo}/pulls?state=closed"
      repo_bound_item(user, repo, pullreq_id, :pull_requests,
                      [open, closed],
                      {'repo' => repo, 'owner' => user,
                       'number' => pullreq_id},
                      'number')
    end

    def retrieve_forks(user, repo)
      repo_bound_items(user, repo, :forks,
                       ["repos/#{user}/#{repo}/forks"],
                       {'repo' => repo, 'owner' => user},
                       'id', item = nil, refresh = false, order = :asc)
    end

    def retrieve_fork(user, repo, fork_id)
      repo_bound_item(user, repo, fork_id, :forks,
                       ["repos/#{user}/#{repo}/forks"],
                       {'repo' => repo, 'owner' => user},
                       'id')
    end

    def retrieve_pull_req_commits(user, repo, pullreq_id)
      pr_commits = paged_api_request(ghurl "repos/#{user}/#{repo}/pulls/#{pullreq_id}/commits")

      pr_commits.map do |x|
        head_user = x['url'].split(/\//)[4]
        head_repo = x['url'].split(/\//)[5]

        retrieve_commit(head_repo, x['sha'], head_user)
      end.select{|x| not x.nil?}
    end

    def retrieve_pull_req_comments(owner, repo, pullreq_id)
      review_comments_url = ghurl "repos/#{owner}/#{repo}/pulls/#{pullreq_id}/comments"

      url = review_comments_url
      retrieved_comments = paged_api_request url

      retrieved_comments.each do |x|
        x['owner'] = owner
        x['repo'] = repo
        x['pullreq_id'] = pullreq_id.to_i

        if persister.find(:pull_request_comments, {'owner' => owner,
                                                   'repo' => repo,
                                                   'pullreq_id' => pullreq_id,
                                                   'id' => x['id']}).empty?
          persister.store(:pull_request_comments, x)
        end
      end

      persister.find(:pull_request_comments, {'owner' => owner, 'repo' => repo,
                                              'pullreq_id' => pullreq_id})
    end

    def retrieve_pull_req_comment(owner, repo, pullreq_id, comment_id)
      comment = persister.find(:pull_request_comments, {'repo' => repo,
                                                 'owner' => owner,
                                                 'pullreq_id' => pullreq_id.to_i,
                                                 'id' => comment_id}).first
      if comment.nil?
        r = api_request(ghurl "repos/#{owner}/#{repo}/pulls/comments/#{comment_id}")

        if r.nil? or r.empty?
          warn "Could not find pullreq_comment #{owner}/#{repo} #{pullreq_id}->#{comment_id}. Deleted?"
          return
        end

        r['repo'] = repo
        r['owner'] = owner
        r['pullreq_id'] = pullreq_id.to_i
        persister.store(:pull_request_comments, r)
        info "Added pullreq_comment #{owner}/#{repo} #{pullreq_id}->#{comment_id}"
        persister.find(:pull_request_comments, {'repo' => repo, 'owner' => owner,
                                         'pullreq_id' => pullreq_id.to_i,
                                         'id' => comment_id}).first
      else
        debug "Pull request comment #{owner}/#{repo} #{pullreq_id}->#{comment_id} exists"
        comment
      end
    end

    def retrieve_issues(user, repo, refr = false)
      open = "repos/#{user}/#{repo}/issues"
      closed = "repos/#{user}/#{repo}/issues?state=closed"
      repo_bound_items(user, repo, :issues,
                       [open, closed],
                       {'repo' => repo, 'owner' => user},
                       'number', item = nil, refresh = refr, order = :asc)
    end

    def retrieve_issue(user, repo, issue_id)
      open = "repos/#{user}/#{repo}/issues"
      closed = "repos/#{user}/#{repo}/issues?state=closed"
      repo_bound_item(user, repo, issue_id, :issues,
                      [open, closed],
                      {'repo' => repo, 'owner' => user},
                      'number')
    end

    def retrieve_issue_events(owner, repo, issue_id)
      url = ghurl "repos/#{owner}/#{repo}/issues/#{issue_id}/events"
      retrieved_events = paged_api_request url

      issue_events = retrieved_events.map { |x|
        x['owner'] = owner
        x['repo'] = repo
        x['issue_id'] = issue_id

        if persister.find(:issue_events, {'owner' => owner,
                                          'repo' => repo,
                                          'issue_id' => issue_id,
                                          'id' => x['id']}).empty?
          info "Added issue_event #{owner}/#{repo} #{issue_id}->#{x['id']}"
          persister.store(:issue_events, x)
        end
        x
      }
      a = persister.find(:issue_events, {'owner' => owner, 'repo' => repo,
                                         'issue_id' => issue_id})
      if a.empty? then issue_events else a end
    end

    def retrieve_issue_event(owner, repo, issue_id, event_id)
      event = persister.find(:issue_events, {'repo' => repo,
                                             'owner' => owner,
                                             'issue_id' => issue_id,
                                             'id' => event_id}).first
      if event.nil?
        r = api_request(ghurl "repos/#{owner}/#{repo}/issues/events/#{event_id}")

        if r.nil? or r.empty?
          warn "Could not find issue_event #{owner}/#{repo} #{issue_id}->#{event_id}. Deleted?"
          return
        end

        r['repo'] = repo
        r['owner'] = owner
        r['issue_id'] = issue_id
        persister.store(:issue_events, r)
        info "Added issue_event #{owner}/#{repo} #{issue_id}->#{event_id}"
        a = persister.find(:issue_events, {'repo' => repo, 'owner' => owner,
                                       'issue_id' => issue_id,
                                       'id' => event_id}).first
        if a.nil? then r else a end
      else
        debug "Issue event #{owner}/#{repo} #{issue_id}->#{event_id} exists"
        event
      end
    end

    def retrieve_issue_comments(owner, repo, issue_id)
      url = ghurl "repos/#{owner}/#{repo}/issues/#{issue_id}/comments"
      retrieved_comments = paged_api_request url

      comments = retrieved_comments.each { |x|
        x['owner'] = owner
        x['repo'] = repo
        x['issue_id'] = issue_id

        if persister.find(:issue_comments, {'owner' => owner,
                                            'repo' => repo,
                                            'issue_id' => issue_id,
                                            'id' => x['id']}).empty?
          persister.store(:issue_comments, x)
        end
        x
      }
      a = persister.find(:issue_comments, {'owner' => owner, 'repo' => repo,
                                           'issue_id' => issue_id})
      if a.empty? then comments else a end
    end

    def retrieve_issue_comment(owner, repo, issue_id, comment_id)
      comment = persister.find(:issue_comments, {'repo' => repo,
                                                 'owner' => owner,
                                                 'issue_id' => issue_id,
                                                 'id' => comment_id}).first
      if comment.nil?
        r = api_request(ghurl("repos/#{owner}/#{repo}/issues/comments/#{comment_id}"),
                        media_type = 'application/vnd.github.squirrel-girl-preview') # volatile: https://developer.github.com/v3/issues/comments/#reactions-summary

        if r.nil? or r.empty?
          warn "Could not find issue_comment #{owner}/#{repo} #{issue_id}->#{comment_id}. Deleted?"
          return
        end

        r['repo'] = repo
        r['owner'] = owner
        r['issue_id'] = issue_id
        persister.store(:issue_comments, r)
        info "Added issue_comment #{owner}/#{repo} #{issue_id}->#{comment_id}"
        a = persister.find(:issue_comments, {'repo' => repo, 'owner' => owner,
                                         'issue_id' => issue_id,
                                         'id' => comment_id}).first
        if a.nil? then r else a end
      else
        debug "Issue comment #{owner}/#{repo} #{issue_id}->#{comment_id} exists"
        comment
      end
    end

    def retrieve_repo_labels(owner, repo, refr = false)
      repo_bound_items(owner, repo, :repo_labels,
                       ["repos/#{owner}/#{repo}/labels"],
                       {'repo' => repo, 'owner' => owner},
                       'name', item = nil, refresh = refr, order = :asc)
    end

    def retrieve_repo_label(owner, repo, name)
      repo_bound_item(owner, repo, name, :repo_labels,
                       ["repos/#{owner}/#{repo}/labels"],
                       {'repo' => repo, 'owner' => owner},
                       'name')
    end

    def retrieve_issue_labels(owner, repo, issue_id)
      url = ghurl("repos/#{owner}/#{repo}/issues/#{issue_id}/labels")
      paged_api_request(url)
    end

    def retrieve_topics(owner, repo)
      # volatile: currently available with api preview
      # https://developer.github.com/v3/repos/#list-all-topics-for-a-repository
      stored_topics = persister.find(:topics, {'owner' => owner, 'repo' => repo })

      url = ghurl("repos/#{owner}/#{repo}/topics")
      r = api_request(url, media_type = "application/vnd.github.mercy-preview+json")

      if r.nil? or r.empty? or r['names'].nil? or r['names'].empty?
        warn "No topics for #{owner}/#{repo}"
        return
      end

      topics = r['names']
      if topics.nil? or topics.empty?
        return
      end

      topics.each do |topic|
        if stored_topics.select{|x| x['topic'] == topic}.empty?
          topic_entry = {
            :owner => owner,
            :repo  => repo,
            :topic => topic
          }
          persister.store(:topics, topic_entry)
          info "Added topic #{topic} -> #{owner}/#{repo}"
        else
          debug "Topic #{topic} -> #{owner}/#{repo} exists"
        end
      end

      r['names']
    end

    # Get current Github events
    def get_events
      api_request "https://api.github.com/events"
    end

    # Get all events for the specified repo.
    # GitHub will only return 90 days of events
    def get_repo_events(owner, repo)
      url = ghurl("repos/#{owner}/#{repo}/events")
      r = paged_api_request(url)

      r.each do |e|
        unless get_event(e['id']).empty?
          debug "Repository event #{owner}/#{repo} -> #{e['type']}-#{e['id']} already exists"
        else
          persister.store(:events, e)
          info "Added event for repository #{owner}/#{repo} -> #{e['type']}-#{e['id']}"
        end
      end

      persister.find(:events, {'repo.name' => "#{owner}/#{repo}"})

    end

    # Get a specific event by +id+.
    def get_event(id)
      persister.find(:events, {'id' => id})
    end

    # Retrieve diff between two branches. If either branch name is not provided
    # the branch name is resolved to the corresponding default branch
    def retrieve_master_branch_diff(owner, repo, branch, parent_owner, parent_repo, parent_branch)
      branch   = retrieve_default_branch(owner, repo) if branch.nil?
      parent_branch = retrieve_default_branch(parent_owner, parent_repo) if parent_branch.nil?
      return nil if branch.nil? or parent_branch.nil?

      cmp_url = "https://api.github.com/repos/#{parent_owner}/#{parent_repo}/compare/#{parent_branch}...#{owner}:#{branch}"
      api_request(cmp_url)
    end

    # Retrieve the default branch for a repo. If nothing is retrieved, 'master' is returned
    def retrieve_default_branch(owner, repo, refresh = false)
      retrieved = retrieve_repo(owner, repo, refresh)
      return nil if retrieved.nil?

      master_branch = 'master'
      if retrieved['default_branch'].nil?
        # The currently stored repo entry has been created before the
        # default_branch field was added to the schema
        retrieved = retrieve_repo(owner, repo, true)
        return nil if retrieved.nil?
      end
      master_branch = retrieved['default_branch'] unless retrieved.nil?
      master_branch
    end

    private

    def restricted_page_request(url, pages)
      if pages != -1
        paged_api_request(url, pages)
      else
        paged_api_request(url)
      end
    end

    def repo_bound_items(user, repo, entity, urls, selector, discriminator,
        item_id = nil, refresh = false, order = :asc, media_type = '')

       urls.each do |url|
        total_pages = num_pages(ghurl url)

        page_range = if order == :asc
                       (1..total_pages)
                     else
                       total_pages.downto(1)
                     end

        page_range.each do |page|
          items = api_request(ghurl(url, page), media_type)
          break if items.nil?

          items.each do |x|
            x['repo'] = repo
            x['owner'] = user

            instances = repo_bound_instance(entity, selector,
                                            discriminator, x[discriminator])
            exists = !instances.empty?

            unless exists
              x = api_request(x['url'], media_type)
              break if x.nil?
              x['repo'] = repo
              x['owner'] = user
              persister.store(entity, x)
              info "Added #{entity} #{user}/#{repo} -> #{x[discriminator]}"
            else
              if refresh
                instances.each do |i|

                  id = if i[discriminator].to_i.to_s != i[discriminator]
                         i[discriminator] # item_id is int
                       else
                         i[discriminator].to_i # convert to int
                       end

                  instance_selector = selector.merge({discriminator => id})
                  persister.upsert(entity, instance_selector, x)
                  debug "Refreshing #{entity} #{user}/#{repo} -> #{x[discriminator]}"
                end
              else
                debug "#{entity} #{user}/#{repo} -> #{x[discriminator]} exists"
              end
            end

            # If we are just looking for a single item, give the method a chance
            # to return as soon as we find it. This is to avoid loading all
            # items before we actually search for what we are looking for.
            unless item_id.nil?
              a = repo_bound_instance(entity, selector, discriminator, item_id)
              unless a.empty?
                return a
              end
            end
          end
        end
      end

      if item_id.nil?
        persister.find(entity, selector)
      else
        # If the item we are looking for has been found, the method should
        # have returned earlier. So just return an empty result to indicate
        # that the item has not been found.
        []
      end
    end

    def repo_bound_item(user, repo, item_id, entity, url, selector,
                        discriminator, order = :asc, media_type = '')
      stored_item = repo_bound_instance(entity, selector, discriminator, item_id)

      r = if stored_item.empty?
            repo_bound_items(user, repo, entity, url, selector, discriminator,
                             item_id, false, order, media_type).first
          else
            stored_item.first
          end
      if r.nil?
        warn "Could not find #{entity} #{user}/#{repo} -> #{item_id}. Deleted?"
      end
      r
    end

    def repo_bound_instance(entity, selector, discriminator, item_id)

      id = if item_id.to_i.to_s != item_id
             item_id # item_id is int
           else
             item_id.to_i # convert to int
           end

      instance_selector = selector.merge({discriminator => id})
      result = persister.find(entity, instance_selector)
      if result.empty?
        # Try without type conversions. Useful when the discriminator type
        # is string and an item_id that can be converted to int is passed.
        # Having no types sucks occasionaly...
        instance_selector = selector.merge({discriminator => item_id})
        persister.find(entity, instance_selector)
      else
        result
      end
    end

    def ghurl(path, page = -1, per_page = 100)
      if page > 0
        if path.include?('?')
          path = path + "&page=#{page}&per_page=#{per_page}"
        else
          path = path + "?page=#{page}&per_page=#{per_page}"
        end
        config(:mirror_urlbase) + path
      else
        if path.include?('?')
          path = path + "&per_page=#{per_page}"
        else
          path = path + "?per_page=#{per_page}"
        end
        config(:mirror_urlbase) + path
      end
    end

  end
end
