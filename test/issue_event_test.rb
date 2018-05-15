require 'test_helper'

class GhtIssueEventTest < Minitest::Test
  describe 'ghtorrent issue events tests' do
    before do
      session = 1
      @ght = GHTorrent::Mirror.new(session)
      @db = @ght.db
    end

    it 'should call ensure_issue_event method with saved issue_event - doesnt update issue_event' do
      @db.transaction(:rollback=>:always) do
        user = create(:user, db_obj: @db)
        
        repo = create(:repo, :github_project, { owner_id: user.id, 
            owner: { 'login' => user.name_email }, db_obj: @db } )
        
        pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                                db_obj: @db })
        issue = create(:issue,:github_issue, {repo_id: repo.id, db_obj: @db})
                    
        issue_event = create(:issue_event,:github_issue_event, {issue_id: issue.id, actor_id: user.id, db_obj: @db})
        # Need to nil out pull_request stores value as integer but tests for nil?  -- this is a problem
        issue.pull_request = nil

        @ght.stubs(:retrieve_issues).returns([issue])
        @ght.stubs(:retrieve_issue).returns(issue)
        @ght.stubs(:retrieve_issue_events).returns ([issue_event])
        @ght.stubs(:retrieve_issue_event).returns issue_event

        retval = @ght.ensure_issue_event(user.name_email, repo.name,
            issue.issue_id, issue_event.event_id)
        assert retval
        
        refute retval[:issue_id] == issue.issue_id.to_i
      end
    end

    it 'should successfully call ensure_issue_events method' do
      user = create(:user, db_obj: @db)
          
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }, db_obj: @db } )
      
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
                              db_obj: @db })
      issue = create(:issue,:github_issue, {repo_id: repo.id, db_obj: @db})
              
      issue_event = create(:issue_event,:github_issue_event, {issue_id: issue.id, actor_id: user.id})
      # Need to nil out pull_request stores value as integer but tests for nil?  -- this is a problem
      issue.pull_request = nil
  
      @ght.stubs(:ensure_repo).returns repo
      @ght.stubs(:retrieve_issues).returns([issue])
      @ght.stubs(:retrieve_issue).returns(issue)
      @ght.stubs(:retrieve_issue_events).returns ([issue_event])
      @ght.stubs(:retrieve_issue_event).returns issue_event
  
      retval = @ght.ensure_issue_events(user.name_email, user.name_email, repo.name)
      assert retval
    end

    it 'should call ensure_issue_event method(s) nil cases' do
      user = create(:user)
      repo = create(:repo, :github_project, {  owner: { 'login' => user.name_email } } )
      issue = create(:issue,:github_issue)
      issue_event = create(:issue_event, :github_issue_event )
  
      @ght.stubs(:ensure_repo).returns nil
      
      retval = @ght.ensure_issue_events(user.name_email, repo.name, issue.issue_id)
      refute retval
  
      retval = @ght.ensure_issue_event(user.name_email, repo.name, issue_event.issue_id, issue_event.event_id)
      refute retval
  
      @ght.stubs(:ensure_repo).returns repo
      @ght.stubs(:ensure_issue).returns nil
      @ght.stubs(:retrieve_issue_event).returns nil
      retval = @ght.ensure_issue_events(user.name_email, repo.name, issue.issue_id)
      refute retval
  
      retval = @ght.ensure_issue_event(user.name_email, repo.name, issue_event.issue_id, issue_event.event_id)
      refute retval
  
      @ght.stubs(:ensure_issue).returns issue
      retval = @ght.ensure_issue_event(user.name_email, repo.name, issue_event.issue_id, issue_event.event_id)
      refute retval
  
      @ght.stubs(:retrieve_issue_event).returns issue_event
      issue_event.actor = nil 
  
      retval = @ght.ensure_issue_event(user.name_email, repo.name, issue_event.issue_id, issue_event.event_id)
      refute retval
    end

    it 'should call ensure_issue_event method with nil assignee' do
      @db.transaction(:rollback=>:always) do
        user = create(:user, db_obj: @db)
      
        repo = create(:repo, :github_project, { owner_id: user.id, 
            owner: { 'login' => user.name_email }, db_obj: @db } )
        
        commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
              author: user,
              committer: user,
              commit:  { :comment_count => 0, :author => user, :committer => user},
              parents: [], db_obj: @db} )  
      
          pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
              base_commit_id: commit.id, db_obj: @db })
      
          issue = create(:issue,:github_issue, {repo_id: repo.id, db_obj: @db})
          
          issue_event = create(:issue_event,:github_issue_event, {issue_id: issue.id, 
              actor_id: user.id, event: 'assigned', actor:  {'login' => user.name_email}})
      
          @ght.stubs(:retrieve_issues).returns([issue])
          @ght.stubs(:retrieve_issue).returns(issue)
          @ght.stubs(:retrieve_issue_events).returns ([issue_event])
          @ght.stubs(:retrieve_issue_event).returns issue_event
      
          issue.pull_request = nil
      
          retval = @ght.ensure_issue_event(user.name_email, repo.name,issue.issue_id, issue_event.event_id)
          assert retval
          assert retval[:issue_id].must_equal issue.id
      end
    end
  
    it 'should call ensure_issue_event method with actor login' do
        @db.transaction(:rollback=>:always) do
          user = create(:user, db_obj: @db)
          
          repo = create(:repo, :github_project, { owner_id: user.id, 
              owner: { 'login' => user.name_email }, db_obj: @db } )
          
          commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
              author: user,
              committer: user,
              commit:  { :comment_count => 0, :author => user, :committer => user},
              parents: [], db_obj: @db} )  
  
          pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
              base_commit_id: commit.id, db_obj: @db })
  
          issue = create(:issue,:github_issue, {repo_id: repo.id, assignee_id: user.id, db_obj: @db})
          
          issue_event = create(:issue_event,:github_issue_event, {issue_id: issue.id, 
              actor_id: user.id, event: 'assigned', action: 'assigned', actor:  {'login' => user.name_email}})
  
          @ght.stubs(:retrieve_issues).returns([issue])
          @ght.stubs(:retrieve_issue).returns(issue)
          @ght.stubs(:retrieve_issue_events).returns ([issue_event])
          @ght.stubs(:retrieve_issue_event).returns issue_event
  
          issue.pull_request = nil
  
          retval = @ght.ensure_issue_event(user.name_email, repo.name,issue.issue_id, issue_event.event_id)
          assert retval
          assert retval[:issue_id].must_equal issue.id
      end
    end
  end
end