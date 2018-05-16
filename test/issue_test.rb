require 'test_helper'

class GhtIssueTest
  describe 'ghtorrent issues tests' do
    around do | test | 
      ght_trx do
        test.call
      end
    end

    before do
      @ght = ght
      @db = db
    end

    # it 'should call ensure_issues method' do
    #   user = create(:user, db_obj: @db)
      
    #   repo = create(:repo, :github_project, { owner_id: user.id, 
    #       owner: { 'login' => user.name_email }, db_obj: @db } )
      
    #   pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
    #                           db_obj: @db })
    #   issue = create(:issue,:github_issue, {repo_id: repo.id, db_obj: @db})
      
    #   # Need to nil out pull_request stores value as integer but tests for nil?  -- this is a problem
    #   issue.pull_request = nil
    #   @ght.stubs(:retrieve_issues).returns([issue])
    #   @ght.stubs(:retrieve_issue).returns(issue)
    #   @ght.stubs(:ensure_issue_events).returns nil
    #   @ght.stubs(:ensure_issue_comments).returns nil
    #   @ght.stubs(:ensure_issue_labels).returns nil
    #   retval = @ght.ensure_issues(user.name_email, repo.name)
    #   assert retval
    #   assert retval[0][:id].must_equal issue.id
    #   assert retval[0][:repo_id].must_equal repo.id
    # end

    it 'should call ensure_issues method with an unsaved repo' do
      user = create(:user)
      
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }} )
      
      @ght.stubs(:ensure_repo).returns(nil)
  
      retval = @ght.ensure_issues(user.name_email, repo.name)
      refute retval
    end

    it 'should call ensure_issues method with unsaved issue' do
      user = create(:user, db_obj: @db)
      
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }, db_obj: @db } )
      
      issue = create(:issue,:github_issue, {repo_id: repo.id})
      
      @ght.stubs(:retrieve_issues).returns([issue])
      @ght.stubs(:retrieve_issue).returns(nil)

      retval = @ght.ensure_issues(user.name_email, repo.name)
      assert retval.empty?
    end

    it 'should call ensure_issues method with pull_request/patch_url not nil ' do
      user = create(:user, db_obj: @db)
      
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }, db_obj: @db } )
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              db_obj: @db })
      issue = create(:issue,:github_issue, {repo_id: repo.id, db_obj: @db})
      
      # Need to nil out pull_request stores value as integer but tests for nil?  -- this is a problem
      # now we need to change pull request to a hash
      issue.pull_request = {'id' => pull_request.id, 'patch_url' => 'not nil'}
      @ght.stubs(:retrieve_issues).returns([issue])
      @ght.stubs(:retrieve_issue).returns(issue)
      @ght.stubs(:retrieve_pull_request).returns nil
      @ght.stubs(:ensure_issue_events).returns nil
      @ght.stubs(:ensure_issue_comments).returns nil
      @ght.stubs(:ensure_issue_labels).returns nil
      retval = @ght.ensure_issues(user.name_email, repo.name)
      assert retval
      assert retval[0][:id].must_equal issue.id
      assert retval[0][:repo_id].must_equal repo.id
    end

    it 'should call ensure_issues method with pull_request/patch_url not nil and pull_request not nil ' do
      user = create(:user, db_obj: @db)
      
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }, db_obj: @db } )
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              db_obj: @db })
      issue = create(:issue,:github_issue, {repo_id: repo.id, db_obj: @db})
      
      # Need to nil out pull_request stores value as integer but tests for nil?  -- this is a problem
      # now we need to change pull request to a hash
      issue.pull_request = {'id' => pull_request.id, 'patch_url' => 'not nil'}        
      @ght.stubs(:retrieve_issues).returns([issue])
      @ght.stubs(:retrieve_issue).returns(issue)
      @ght.stubs(:ensure_pull_request).returns pull_request
      @ght.stubs(:ensure_issue_events).returns nil
      @ght.stubs(:ensure_issue_comments).returns nil
      @ght.stubs(:ensure_issue_labels).returns nil      
      retval = @ght.ensure_issues(user.name_email, repo.name)
      refute retval.empty?
      assert retval[0][:id].must_equal issue.id
      assert retval[0][:repo_id].must_equal repo.id
    end

    it 'should call ensure_issue with unsaved repo' do
      user = create(:user)
      repo = create(:repo, :github_project, {} )
      fake_issue_id = Faker::Number.number(3).to_i
      
      @ght.stubs(:ensure_repo).returns nil
  
      retval = @ght.ensure_issue(user.name_email, repo.name, fake_issue_id, false, false, false)
      refute retval
    end

    it 'should call ensure_issue method with unsaved issue' do
      user = create(:user, db_obj: @db)
        
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }, db_obj: @db } )
        
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              db_obj: @db })
      issue = create(:issue,:github_issue, {repo_id: repo.id})
        
      # Need to nil out pull_request stores value as integer but tests for nil?  -- this is a problem
      # now we need to change pull request to a hash
      issue.pull_request = {'patch_url' => 'not nil'}
      @ght.stubs(:retrieve_issues).returns([issue])
      @ght.stubs(:retrieve_issue).returns(issue)
      @ght.stubs(:retrieve_pull_request).returns nil
      @ght.stubs(:ensure_issue_events).returns nil
      @ght.stubs(:ensure_issue_comments).returns nil
      @ght.stubs(:ensure_issue_labels).returns nil
      @ght.stubs(:ensure_user).returns user
      
      fake_issue_id = Faker::Number.number(3).to_i
      
      retval = @ght.ensure_issue(user.name_email, repo.name, fake_issue_id, false, false, false)
      assert retval
      assert retval[:issue_id].must_equal fake_issue_id
      assert retval[:repo_id].must_equal repo.id
    end

    it 'should call ensure_issue method with ensure_pull_request' do
      user = create(:user, db_obj: @db)
      
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }, db_obj: @db } )
      
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
          author: user,
          committer: user,
          commit:  { :comment_count => 0, :author => user, :committer => user},
          parents: [], db_obj: @db} )    
      
      #    Need to create pull request with a new user and project.  This will 
      #   be checked by ensure_pull_request method
      pr_name = "#{user.name}<#{user.email}>" 
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
              base_commit_id: commit.id,                    
              base: { 'repo' => { 'owner' => { 'login' => pr_name }, 
                          'name' => repo.name }, 'sha' => SecureRandom.hex },   
              db_obj: @db })
      name, email = pull_request.base['repo']['owner']['login'].split("<")
      email = email.split(">")[0]  
      pr_user = create(:user, {name: name, email: email, db_obj: @db})                        
      
      pr_repo = create(:repo, :github_project, { name: repo.name, owner_id: pr_user.id, 
      owner: { 'login' => pr_user.name_email }, db_obj: @db } )                       
      
      issue = create(:issue,:github_issue, {repo_id: repo.id, db_obj: @db})
      
      # Need to nil out pull_request stores value as integer but tests for nil?  -- this is a problem
      # now we need to change pull request to a hash
      issue.pull_request = {'patch_url' => 'not nil'}
      @ght.stubs(:retrieve_issues).returns([issue])
      @ght.stubs(:retrieve_issue).returns(issue)
      @ght.stubs(:retrieve_pull_request).returns pull_request
      @ght.stubs(:ensure_issue_events).returns nil
      @ght.stubs(:ensure_issue_comments).returns nil
      @ght.stubs(:ensure_issue_labels).returns nil
      @ght.stubs(:ensure_commit).returns(commit)
      retval = @ght.ensure_issue(user.name_email, repo.name, issue.issue_id, false, false, false)
      assert retval
      
      assert retval[:issue_id].must_equal issue.issue_id.to_i
      assert retval[:repo_id].must_equal repo.id
    end
  end
end
