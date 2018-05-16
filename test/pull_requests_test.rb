require 'test_helper'

class GhtPullRequestTest
  describe 'ghtorrent pull request tests' do
    around do | test | 
      ght_trx do
        test.call
      end
    end

    before do
      @ght = ght
      @db = db
    end

    it 'should overwrite transient fields' do
      repo = create(:repo, :github_project, { owner_id: 999, 
        owner: {'login' => 'owner_login'}, 
       parent: {'name'  => 'parent_repo', 'owner' => {'login' =>'parent_login'}} } )
    end

    it 'should create a github pull request' do
      github_pr = create(:pull_request, :github_pr)
      pr = create(:pull_request)
    end

   it 'should create a pull request comment' do
      user = create(:user, db_obj: @ght.db)
      
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, db_obj: @ght.db } )
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [],  db_obj: @ght.db } )
    
      now = DateTime.now.strftime('%FT%T%:z')               
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                            merged_at: now, 
                            base_commit_id: commit.id,
                            db_obj: @ght.db })
      assert pull_request.merged_at.must_equal now   
      refute pull_request.closed_at  
      comments = create(:pull_request_comment, :github_pr_comment, {user_id: user.id, 
              pull_request_id: pull_request.id,
              commit_id: commit.id, 
              user: {'login' => user.login}, original_position: 5, db_obj: @ght.db}) 
      assert comments.original_position.must_equal 5
      assert comments.original_commit_id.must_equal comments.commit_id                    
   end

    it 'should call ensure_pull_requests method' do
      user = create(:user, db_obj: @ght.db)
  
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )

      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
  
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id })
                              
      @ght.stubs(:retrieve_user_byemail).returns(user)                        
      @ght.stubs(:ensure_repo).returns(repo)
      @ght.stubs(:ensure_commit).returns(commit)
      @ght.stubs(:ensure_pull_request_commits).returns(nil)
      @ght.stubs(:ensure_pullreq_comments).returns(nil)
      @ght.stubs(:ensure_issue_comments).returns(nil)

      @ght.stubs(:retrieve_pull_requests).returns([pull_request])
      @ght.stubs(:retrieve_pull_request).returns(pull_request)

      retval = @ght.ensure_pull_requests(user.name_email, repo.name)
      assert retval.length > 0
      assert retval[0][:base_repo_id] == repo.id
    end

    it 'should test ensure_pull_request with saved pull request' do
      user = create(:user, db_obj: @ght.db)
  
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )

      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
  
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id, db_obj: @ght.db})
      
      pull_request['head']['repo']['owner']['login'] =
                pull_request['base']['repo']['owner']['login'] 

      
      @ght.stubs(:retrieve_user_byemail).returns user 
      @ght.stubs(:ensure_repo).returns(repo)
      @ght.stubs(:ensure_commit).returns(commit)
      @ght.stubs(:ensure_pull_request_commits).returns(nil)
      @ght.stubs(:ensure_pullreq_comments).returns(nil)
      @ght.stubs(:ensure_issue_comments).returns(nil)

      @ght.stubs(:retrieve_p_requests).returns([pull_request])
      @ght.stubs(:retrieve_pull_request).returns(pull_request)
    
      retval = @ght.ensure_pull_request(user.name_email, repo.name, pull_request.pullreq_id)
      assert retval.length > 0
      assert retval[:base_repo_id] == repo.id
    end

    it 'should test intra-branch pull request' do
      user = create(:user, db_obj: @ght.db)
  
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )

      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
  
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id, db_obj: @ght.db })

      @ght.stubs(:retrieve_user_byemail).returns(user)  
      @ght.stubs(:ensure_repo).returns(repo)
      @ght.stubs(:ensure_commit).returns(commit)
      @ght.stubs(:ensure_pull_request_commits).returns(nil)
      @ght.stubs(:ensure_pullreq_comments).returns(nil)
      @ght.stubs(:ensure_issue_comments).returns(nil)

      @ght.stubs(:retrieve_pull_requests).returns([pull_request])
      @ght.stubs(:retrieve_pull_request).returns(pull_request)
      @ght.expects(:debug).returns("Added accompanying_issue for pull_req #{pull_request.number} ->").at_least_once
      
      retval = @ght.ensure_pull_requests(user.name_email, repo.name)
      assert retval.length > 0
      assert retval[0][:base_repo_id] == repo.id
    end

    it 'should call ensure_pull_requests method with user and invalid project' do
      @ght.stubs(:ensure_repo).returns(nil)
      retval = @ght.ensure_pull_requests('fake_name', 'fake_email')

      refute retval
    end

    it 'should ensure_pull_requests method with refresh = true' do
      user = create(:user, db_obj: @ght.db)
  
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )

      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
  
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id })

      @ght.stubs(:retrieve_user_byemail).returns(user)  
      @ght.stubs(:ensure_repo).returns(repo)
      @ght.stubs(:ensure_commit).returns(commit)
      @ght.stubs(:ensure_pull_request_commits).returns(nil)
      @ght.stubs(:ensure_pullreq_comments).returns(nil)
      @ght.stubs(:ensure_issue_comments).returns(nil)

      @ght.stubs(:retrieve_pull_requests).returns([pull_request])
      @ght.stubs(:retrieve_pull_request).returns(pull_request)
    
      refresh = true
      retval = @ght.ensure_pull_requests(user.name_email, repo.name, refresh)
      assert retval.length > 0
      assert retval[0][:base_repo_id] == repo.id
    end

    it 'should call ensure_pull_request method with invalid project' do
      user = create(:user, db_obj: @ght.db)
  
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email } } )
                              
      @ght.stubs(:ensure_repo).returns(nil)

      retval = @ght.ensure_pull_request(user.name_email, repo.name, 123)
      refute retval
    end
    
    it 'should call ensure_pull_request method with invalid pull request' do
      user = create(:user, db_obj: @ght.db)
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email } } )
                              
      @ght.stubs(:ensure_repo).returns(repo)
      @ght.stubs(:retrieve_pull_request).returns nil

      retval = @ght.ensure_pull_request(user.name_email, repo.name, 123)
      refute retval
    end

    it 'should test ensure_pullreq_comments method returns empty array' do
      user = create(:user, db_obj: @ght.db)
      
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } ) 
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
      
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id, db_obj: @ght.db })
      
                      
      comments = create(:pull_request_comment, :github_pr_comment, {user_id: user.id, pull_request_id: pull_request.id,
                        commit_id: commit.id, db_obj: @ght.db})          
      @ght.stubs(:retrieve_pull_req_comments).returns(comments)
      @ght.stubs(:ensure_pull_request).returns(nil)

      retval = @ght.ensure_pullreq_comments(user.name_email, repo.name, pull_request.pullreq_id)
      refute retval 

      @ght.stubs(:ensure_pull_request).returns(pull_request)
      @ght.stubs(:retrieve_pull_req_comments).returns([comments]) 
      retval = @ght.ensure_pullreq_comments(user.name_email, repo.name, pull_request.pullreq_id)
      
      assert retval.empty?
    end

    it 'should test ensure_pullreq_comments method without saved comment record returns empty array' do
      user = create(:user, db_obj: @ght.db)
      
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )      
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
      
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id, db_obj: @ght.db })
      
                      
      comments = create(:pull_request_comment, :github_pr_comment, {user_id: user.id, pull_request_id: pull_request.id,
                        commit_id: commit.id})          
      @ght.stubs(:retrieve_pull_req_comments).returns(comments)
      @ght.stubs(:ensure_pull_request).returns(nil)
           
      retval = @ght.ensure_pullreq_comments(user.name_email, repo.name, pull_request.pullreq_id)
      refute retval
      
      @ght.stubs(:ensure_pull_request).returns(pull_request)
      @ght.stubs(:retrieve_pull_req_comments).returns([comments]) 
      retval = @ght.ensure_pullreq_comments(user.name_email, repo.name, pull_request.pullreq_id)
      
      assert retval.empty?
    end

    it 'should test ensure_pullreq_comment method with a nil pull request' do
      user = create(:user, db_obj: @ght.db)
      
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
      
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id, db_obj: @ght.db })
      
                      
      comments = create(:pull_request_comment, :github_pr_comment, {user_id: user.id, pull_request_id: pull_request.id,
                        commit_id: commit.id, original_commit_id: commit.id, 
                        user: {'login' => user.login}})          
      @ght.stubs(:retrieve_pull_req_comments).returns(comments)
      @ght.stubs(:ensure_pull_request).returns(nil)
      retval = @ght.ensure_pullreq_comment(user.name_email, repo.name, pull_request.pullreq_id, comments.comment_id)
      refute retval
      @ght.stubs(:ensure_pull_request).returns(pull_request)
      @ght.stubs(:retrieve_pull_req_comment).returns(comments) 
      @ght.stubs(:ensure_commit).returns(commit)
      retval = @ght.ensure_pullreq_comment(user.name_email, repo.name, pull_request.pullreq_id, comments.comment_id)
      
      assert retval
    end

    it 'should handle remaining nil cases' do
      user = create(:user, db_obj: @ght.db)
      
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
      
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id, db_obj: @ght.db })
      
                      
      comments = create(:pull_request_comment, :github_pr_comment, {user_id: user.id, pull_request_id: pull_request.id,
                        commit_id: commit.id, original_commit_id: commit.id, 
                        user: {'login' => user.login}, db_obj: @ght.db})          
      @ght.stubs(:ensure_pull_request).returns pull_request
      @ght.stubs(:retrieve_pull_req_comment).returns(nil)
      
      retval = @ght.ensure_pullreq_comment(user.name_email, repo.name, pull_request.pullreq_id, comments.comment_id, pull_request)
      assert retval    
      pull_request2 = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
        base_commit_id: commit.id })
      
      @ght.stubs(:ensure_pull_request).returns pull_request
      retval = @ght.ensure_pullreq_comment(user.name_email, repo.name, pull_request.pullreq_id, comments.comment_id, pull_request2)
      refute retval
      @ght.stubs(:retrieve_pull_req_comment).returns(comments)
      @ght.stubs(:ensure_user).returns(nil)
      retval = @ght.ensure_pullreq_comment(user.name_email, repo.name, pull_request.pullreq_id, comments.comment_id)
      assert retval
      
      retval = @ght.ensure_pullreq_comment(user.name_email, repo.name, pull_request.pullreq_id, comments.comment_id, pull_request2)
      refute retval
    end

    it 'should call ensure_pull_request_commits method' do
      user = create(:user, db_obj: @ght.db)
  
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )

      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
  
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id, db_obj: @ght.db })

      pr_commit = create(:pull_request_commit, :github_pr_commit, 
                        {pull_request_id: pull_request.id, commit_id: commit.id, repo_name: repo.name, 
                         owner: user.name_email, sha: commit.sha }) 

      @ght.stubs(:retrieve_pull_req_commits).returns([pr_commit])
      @ght.stubs(:ensure_commit).returns(commit)
      @ght.stubs(:retrieve_pull_request_commit).returns(pr_commit)

      
      retval = @ght.ensure_pull_request_commits(user.name_email, repo.name, 
                   pull_request.pullreq_id, pull_request, nil)
      assert retval[0].must_equal true
    end

    it 'should call ensure_pull_request_commits method with nil pull_request' do
      user = create(:user, db_obj: @ght.db)
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )

      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [] } )
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id })

      @ght.stubs(:ensure_pull_request).returns(nil)
      
      retval = @ght.ensure_pull_request_commits(user.name_email, repo.name, 
                   pull_request.pullreq_id, nil, nil)
      refute retval
    end

    it 'should call ensure_pull_request_commits method with saved pull request commit' do
      user = create(:user, db_obj: @ght.db)
      
      # add github fields to user
      user.author = user
      user.committer = user
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, 
        db_obj: @ght.db } )
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
                      author: user,
                      committer: user,
                      commit:  { :comment_count => 0, :author => user, :committer => user},
                      parents: [], db_obj: @ght.db} )
      
      commit['commit']['author'] = user
      commit['commit']['committer'] = user
      commit['commit']['author'].date = commit.created_at
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              base_commit_id: commit.id, db_obj: @ght.db })
      pr_commit = create(:pull_request_commit, :github_pr_commit, 
                        {pull_request_id: pull_request.id, commit_id: commit.id, repo_name: repo.name, 
                         owner: user.name_email, sha: commit.sha, db_obj: @ght.db }) 
      @ght.stubs(:retrieve_pull_req_commits).returns([pr_commit])
      @ght.stubs(:ensure_commit).returns(commit)
      @ght.stubs(:retrieve_pull_request_commit).returns(pr_commit)           
                        
      retval = @ght.ensure_pull_request_commits(user.name_email, repo.name, 
                   pull_request.pullreq_id, pull_request, nil)
                              
      assert retval[0][:pull_request_id].must_equal pull_request.id
      assert retval[0][:commit_id].must_equal commit.id
    end
  end
end
