require 'test_helper'

describe 'GhtCommit' do
  describe 'ghtorrent transaction test' do
    run_tests_in_transaction

    it 'should call ensure_commit_comment' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      commit:  { :comment_count.to_s => 3},
                      parents: [],
                      db_obj: db})

      ght.stubs(:retrieve_commit_comment).returns nil

      ght.ensure_commit_comment(user.name_email, repo.name, repo.sha, 1)
    end

    it 'should call ensure_commit_comment' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                       commit:  { :comment_count.to_s => 3},
                       parents: [],
                       db_obj: db})

      comment = create(:commit_comment, :github_comment, {id:  Faker::Number.number(4), commit_id: commit.id,
                        user_id: user.id, user: {'login' => user.name_email}})
      ght.stubs(:retrieve_commit_comment).returns comment
      ght.stubs(:retrieve_commit_comments).returns commit
      ght.stubs(:retrieve_commit).returns(commit)
      ght.stubs(:persist_repo).returns repo

      retval = ght.ensure_commit_comment(user.name_email, repo.name, commit.sha, comment.id)

      assert retval && retval[:comment_id] == comment.id.to_i
    end

    it 'should call ensure_commit_comment with unsaved commit and comment' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})

      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,
      author: user,
      committer: user,
      commit:  { :comment_count => 0, :author => user, :committer => user},
                  parents: [] } )

      comment = create(:commit_comment, :github_comment, {id:  Faker::Number.number(4), commit_id: commit.id,
                        user_id: user.id, user: {'login' => user.name_email}})

      ght.stubs(:retrieve_commit_comment).returns comment
      ght.stubs(:retrieve_commit_comments).returns commit
      ght.stubs(:retrieve_commit).returns(commit)
      ght.stubs(:ensure_commit).returns nil

      retval = ght.ensure_commit_comment(user.name_email, repo.name, commit.sha, comment.id)
      refute retval
    end

    it 'should call ensure_commit_comment with invalid retrieved user login' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})

      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,
      author: user,
      committer: user,
      commit:  { :comment_count => 0, :author => user, :committer => user},
      parents: [], db_obj: db} )

      comment = create(:commit_comment, :github_comment, {id:  Faker::Number.number(4), commit_id: commit.id,
                      user_id: user.id,
                      user: {'login' => user.login} })

      ght.stubs(:retrieve_commit_comment).returns comment
      ght.stubs(:retrieve_commit_comments).returns commit
      ght.stubs(:retrieve_commit).returns(commit)
      ght.stubs(:ensure_commit).returns commit
      ght.stubs(:ensure_user).returns nil

      ght.expects(:warn).returns("Could not ensure user: #{comment['user']['login']}")

      retval = ght.ensure_commit_comment(user.name_email, repo.name, commit.sha, comment.id)
      refute retval
    end

    it 'should call ensure_commit_comment with saved commit and comment' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})

      commit = create(:sha, {project_id: repo.id, committer_id: user.id,
      db_obj: db} )

      comment = create(:commit_comment, :github_comment, {commit_id: commit.id,
        user_id: user.id, user: {'login' => user.name_email}, db_obj: db})

      ght.stubs(:retrieve_commit_comment).returns comment
      ght.stubs(:retrieve_commit_comments).returns [comment]
      ght.stubs(:retrieve_commit).returns(commit)
      ght.stubs(:ensure_commit).returns commit
      ght.expects(:info).returns("Added commit_comment #{user.name_email}/#{repo.name} -> #{commit.sha}/#{comment.id} by user #{user.login}")

      retval = ght.ensure_commit_comment(user.name_email, repo.name, commit.sha, comment.id)
      assert retval
      assert retval[:comment_id].must_equal comment.id
    end

    it 'should call commit_user with unsaved githubuser' do
      githubuser = create(:user)
      commituser = create(:user)
      ght.stubs(:retrieve_user_byemail).returns nil

      retval = ght.commit_user(githubuser, commituser)
    end

    it 'should call commit_user with non-existing login' do
      githubuser = create(:user )
      commituser = create(:user, db_obj: db)
      commituser.login = Faker::Internet.user_name
      ght.stubs(:retrieve_user_byemail).returns nil
      ght.stubs(:ensure_user_byuname).returns(nil)

      retval = ght.commit_user(githubuser, commituser)
    end


    it 'calls ensure_commit method' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      commit:  { :comment_count.to_s => 3},
                      parents: [],
                      db_obj: db})

      ght.stubs(:retrieve_commit).returns(commit)
      ght.stubs(:retrieve_commit_comments).returns []
      ght.stubs(:persist_repo).returns repo
      sha = commit.sha

      db_commit = ght.ensure_commit(repo.name, sha, user.name_email)

      assert db_commit[:sha] == sha
      assert db_commit[:project_id] == repo.id
    end

    it 'calls retrieve commit for a repo that doesn''t exist' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                          commit:  { :comment_count => 0},
                          parents: []})

      ght.stubs(:retrieve_commit).returns(nil)
      ght.stubs(:persist_repo).returns repo
      sha = commit.sha
      returned_commit = ght.ensure_commit(repo.name, sha, user.name_email)
      assert returned_commit.nil?
    end

    it 'calls ensure_commits method with saved commit' do
      user = create(:user, db_obj: db)

      repo = create(:repo, { owner_id: user.id, db_obj: db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                          commit:  { :comment_count => 0},
                          parents: [],
                          db_obj: db})

      ght.stubs(:retrieve_repo).returns(repo)
      ght.stubs(:persist_repo).returns(repo)
      ght.stubs(:retrieve_commit).returns(commit)
      ght.stubs(:retrieve_commits).returns ([commit])
      sha = commit.sha

      retval = ght.ensure_commits(user.name_email, repo.name, sha: sha,
                      return_retrieved: true, fork_all: false)
      assert retval.empty?
    end

    it 'calls ensure_commits method with unsaved saved commit' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      user.date = Time.now.utc.strftime('%F %T')
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      author: user,
                      committer: user,
                      commit:  { 'comment_count' => 0,
                                 'author' => user,
                                 'committer' => user},
                      parents: [] })

       commit2 = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      author: user,
                      committer: user,
                      commit:  { 'comment_count' => 0,
                                 'author' => user,
                                 'committer' => user},
                      parents: [] })

      ght.stubs(:retrieve_repo).returns(repo)
      ght.stubs(:retrieve_commits).returns ([commit,commit2])

      ght.stubs(:retrieve_commit).returns(commit)
      ght.stubs(:persist_repo).returns repo
      sha = commit.sha

      retval = ght.ensure_commits(user.name_email, repo.name, sha: sha,
                      return_retrieved: true, num_commits: 3, fork_all: false)
      assert retval.size.must_equal 2
      assert retval[0][:sha].must_equal commit.sha
    end

    it 'should call ensure_commits with unsaved repo' do
      user = create(:user, db_obj: db)

      fork_repo = create(:repo, :github_project, { owner_id: user.id,
        owner: { 'login' => user.name_email },
        db_obj: db })

      repo = create(:repo, { owner_id: user.id, forked_from: fork_repo.id, db_obj: db})

      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      author: user,
                      committer: user,
                      commit:  { 'comment_count' => 0,
                                 'author' => user,
                                 'committer' => user},
                      parents: [] })

      ght.stubs(:retrieve_repo).returns(nil)
      ght.stubs(:persist_repo).returns(repo)

      ght.stubs(:retrieve_commit).returns(commit)
      sha = commit.sha

      retval = ght.ensure_commits(user.name_email, repo.name, sha: sha,
                      return_retrieved: true, num_commits: 3, fork_all: false)
      refute retval
    end

    it 'should try to store a new commit' do
      user = create(:user, db_obj: db)

      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [] } )

      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at

      ght.stubs(:persist_repo).returns repo
      retval = ght.store_commit(commit, repo.name, user.name_email)

      assert retval[:sha].must_equal commit.sha
    end

    it 'should try to store a new repo and commit' do
      user = create(:user, db_obj: db)

      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id,
        owner: { 'login' => user.name_email },
        db_obj: db })
        
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [] } )

      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at

      ght.stubs(:retrieve_repo).returns(nil)
      ght.stubs(:persist_repo).returns(repo)
      
      retval = ght.store_commit(commit, repo.name, user.name_email)

      assert retval[:sha].must_equal commit.sha
    end

    it 'should call ensure_commit_comments method' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      commit:  { :comment_count.to_s => 3},
                      parents: [],
                      db_obj: db})

      comment = create(:commit_comment, :github_comment, {commit_id: commit.id,
        user_id: user.id, user: {'login' => user.name_email}, db_obj: db})

      ght.stubs(:retrieve_commit).returns(commit)
      ght.stubs(:retrieve_commit_comments).returns([comment])
      ght.stubs(:retrieve_commit_comment).returns(comment)

      ght.ensure_commit_comments(user.name_email, repo.name, commit.sha)
    end

    it 'should call ensure_parents method' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      parent_repo = create(:repo, { owner_id: user.id, db_obj: db})
      parent_commit = create(:commit, :github_commit, {project_id: parent_repo.id, committer_id: user.id,
        commit:  { :comment_count.to_s => 3},
        parents: [],
        db_obj: db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      commit:  { :comment_count.to_s => 3},
                      parents: [parent_repo] ,
                      db_obj: db})

      ght.stubs(:retrieve_commit).returns parent_commit
      retval =  ght.ensure_parents(commit)

      assert retval
      assert retval[0][:commit_id].must_equal commit.id
      assert retval[0][:parent_id].must_equal parent_commit.id
    end

    it 'should call ensure_parents method with unsaved parents' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      parent_repo = create(:repo, { owner_id: user.id, db_obj: db})
      parent_commit = create(:commit, :github_commit, {project_id: parent_repo.id, committer_id: user.id,
          commit:  { :comment_count.to_s => 3},
          parents: []})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      commit:  { :comment_count.to_s => 3},
                      parents: [parent_repo] ,
                      db_obj: db})

      ght.stubs(:retrieve_commit).returns nil

      retval =  ght.ensure_parents(commit)
      assert retval.empty?
    end

    it 'should call ensure_parents method and unable to save parents' do
      user = create(:user, db_obj: db)
      repo = create(:repo, { owner_id: user.id, db_obj: db})
      parent_repo = create(:repo, { owner_id: user.id, db_obj: db})
      parent_commit = create(:commit, :github_commit, {project_id: parent_repo.id, committer_id: user.id,
          commit:  { :comment_count.to_s => 3},
           parents: []})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,
                      commit:  { :comment_count.to_s => 3},
                       parents: [parent_repo] ,
                       db_obj: db})

      ght.stubs(:retrieve_commit).returns parent_commit
      ght.stubs(:store_commit).returns nil

      retval =  ght.ensure_parents(commit)
      assert retval.empty?
    end
  end
end
