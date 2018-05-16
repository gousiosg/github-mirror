require 'test_helper'

class GhtIssueCommentTest
  describe 'ghtorrent issue comments tests' do
    around do | test | 
      ght_trx do
        test.call
      end
    end

    before do
      @ght = ght
      @db = db
    end

    it 'should call ensure_issue_comments method' do
      user = create(:user, db_obj: @ght.db)
      
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }, db_obj: @ght.db } )
      
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
          author: user,
          committer: user,
          commit:  { :comment_count => 0, :author => user, :committer => user},
          parents: [], db_obj: @ght.db} )  
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
          base_commit_id: commit.id, db_obj: @ght.db })
      issue = create(:issue,:github_issue, {repo_id: repo.id, assignee_id: user.id, db_obj: @ght.db})
      issue_comments = create(:issue_comment, :github_comment, 
          { user:  {'login' => user.name_email} } )
      issue.pull_request = nil
      
      @ght.stubs(:retrieve_issues).returns([issue])
      @ght.stubs(:retrieve_issue).returns(issue)
      @ght.stubs(:retrieve_issue_comments).returns ([issue_comments])
      @ght.stubs(:retrieve_issue_comment).returns issue_comments
     
      retval = @ght.ensure_issue_comments(user.name_email, repo.name,issue.issue_id)
      assert retval
      assert retval.first[:issue_id].must_equal issue.id.to_i
    end

    it 'should call ensure_issue_comments with invalid repo' do
      user = create(:user)
      repo = create(:repo )
      issue = create(:issue)
      @ght.stubs(:ensure_repo).returns nil
      @ght.expects(:warn).returns("Could not find repository #{user.name_email}/#{repo.name} for retrieving issue comments for issue #{issue.issue_id}")

      retval = @ght.ensure_issue_comments(user.name_email, repo.name,issue.issue_id)
      refute retval
    end

    it 'should call ensure_issue_comments with invalid issue' do
      user = create(:user)
      repo = create(:repo )
      issue = create(:issue)
      @ght.stubs(:ensure_repo).returns repo
      @ght.expects(:warn).returns("Could not find issue #{user.name_email}/#{repo.name} -> #{issue.issue_id} for retrieving issue comments")
      
      retval = @ght.ensure_issue_comments(user.name_email, repo.name,issue.issue_id, Faker::Number.number(4))
      refute retval
    end

    it 'should call ensure_issue_comment with invalid repo' do
      user = create(:user)
      repo = create(:repo )
      issue = create(:issue)
      @ght.stubs(:ensure_repo).returns nil
      @ght.expects(:warn).returns("Could not find repository #{user.name_email}/#{repo.name} for retrieving issue comments for issue #{issue.issue_id}")
      
      retval = @ght.ensure_issue_comments(user.name_email, repo.name,issue.issue_id)
      refute retval
    end

    it 'should call ensure_issue_comments with invalid issue' do
      user = create(:user)
      repo = create(:repo )
      issue = create(:issue)
      @ght.stubs(:ensure_repo).returns repo
      @ght.expects(:warn).returns("Could not find issue #{user.name_email}/#{repo.name} -> #{issue.issue_id} for retrieving issue comments")
      
      retval = @ght.ensure_issue_comments(user.name_email, repo.name,issue.issue_id, Faker::Number.number(4))
      refute retval
    end

    it 'should call ensure_issue_comment with invalid issue' do
      user = create(:user)
      repo = create(:repo )
      issue = create(:issue)
      comment = create(:commit_comment, {id:  Faker::Number.number(4)})   
      @ght.stubs(:ensure_repo).returns repo
      @ght.expects(:warn).returns("Could not find issue #{user.name_email}/#{repo.name} -> #{issue.issue_id} for retrieving comment #{comment.id}")
      
      retval = @ght.ensure_issue_comment(user.name_email, repo.name,issue.issue_id, comment.id, comment.id)
      refute retval
    end

    it 'should call ensure_issue_comment with invalid issue comment' do
      user = create(:user)
      repo = create(:repo )
      issue = create(:issue)
      comment = create(:commit_comment, {id:  Faker::Number.number(4), db_obj: @db})   
      @ght.stubs(:ensure_repo).returns repo
      @ght.stubs(:ensure_issue).returns issue
      @ght.stubs(:retrieve_issue_comment).returns nil
      @ght.expects(:warn).returns("Could not retrieve issue_comment #{user.name_email}/#{repo.name} -> #{issue.issue_id}/#{comment.id}")
      
      retval = @ght.ensure_issue_comment(user.name_email, repo.name,issue.issue_id, comment.id)
      refute retval
    end

    it 'should call ensure_issue_comment with saved issue comment' do
      user = create(:user, db_obj: @ght.db)
      
      repo = create(:repo, :github_project, { owner_id: user.id, 
          owner: { 'login' => user.name_email }, db_obj: @ght.db } )
      
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,  
          author: user,
          committer: user,
          commit:  { :comment_count => 0, :author => user, :committer => user},
          parents: [], db_obj: @ght.db} )  
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id, 
          base_commit_id: commit.id, db_obj: @ght.db })
      issue = create(:issue,:github_issue, 
        {repo_id: repo.id, assignee_id: user.id, db_obj: @ght.db})
      issue_comments = create(:issue_comment, :github_comment, 
          { issue_id: issue.id, user:  {'login' => user.name_email}, db_obj: @ght.db } )  
      @ght.stubs(:ensure_repo).returns repo
      @ght.stubs(:ensure_issue).returns issue
      @ght.stubs(:retrieve_issue_comment).returns nil
      @ght.expects(:debug)
        .returns("Issue comment #{user.name_email}/#{repo.name} -> #{issue.issue_id}/#{issue_comments.id} exists")
      retval = @ght.ensure_issue_comment(user.name_email, repo.name,issue.issue_id, issue_comments.id)
      assert retval
      assert retval[:issue_id].must_equal issue.id
      assert retval[:comment_id].must_equal issue_comments.id
    end
  end
end


