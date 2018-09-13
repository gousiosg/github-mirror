require 'test_helper'

describe 'GhtIssueLabel' do
  describe 'ghtorrent issue labels tests' do
    run_tests_in_transaction

    it 'should call ensure_issue_labels method with unsaved label' do
      user = create(:user, db_obj: ght.db)

      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email }, db_obj: ght.db } )

      repo_label = create(:repo_label, { repo_id: repo.id, name: repo.name, db_obj: ght.db})
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,
          author: user,
          committer: user,
          commit:  { :comment_count => 0, :author => user, :committer => user},
          parents: [], db_obj: ght.db} )
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id,
          base_commit_id: commit.id, db_obj: ght.db })
      issue = create(:issue,:github_issue, {repo_id: repo.id, assignee_id: user.id, db_obj: ght.db})
      issue_label = create(:issue_label, :github_label,
      {label_id: repo_label.id, issue_id: issue.issue_id, name: repo.name})
      issue.pull_request = nil

      ght.stubs(:retrieve_issue).returns issue
      ght.stubs(:retrieve_issue_labels).returns ([issue_label])
      ght.stubs(:retrieve_issue_label).returns issue_label
      ght.stubs(:retrieve_repo_label).returns repo_label
      ght.expects(:info)
        .returns("Added issue_label #{issue_label.name} to issue #{user.name_email}/#{repo.name} -> #{issue.issue_id}")
      retval = ght.ensure_issue_labels(user.name_email, repo.name, issue.issue_id)
      assert retval
      assert retval[0][:issue_id].must_equal issue.id
    end

    it 'should call ensure_issue_labels method with saved label returns []' do
      user = create(:user, db_obj: ght.db)

      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email }, db_obj: ght.db } )

      repo_label = create(:repo_label,
                { repo_id: repo.id, name: repo.name, db_obj: ght.db})
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,
          author: user,
          committer: user,
          commit:  { :comment_count => 0, :author => user, :committer => user},
          parents: [], db_obj: ght.db} )
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id,
          base_commit_id: commit.id, db_obj: ght.db })
      issue = create(:issue,:github_issue,
              {repo_id: repo.id, assignee_id: user.id, db_obj: ght.db})
      issue_label = create(:issue_label, :github_label,
      {label_id: repo_label.id, issue_id: issue.id, name: repo.name,
       db_obj: ght.db})

      issue.pull_request = nil

      ght.stubs(:retrieve_issue).returns(issue)
      ght.stubs(:retrieve_issue_labels).returns ([issue_label])
      ght.stubs(:retrieve_issue_label).returns issue_label
      ght.stubs(:retrieve_repo_label).returns repo_label

      retval = ght.ensure_issue_labels(user.name_email, repo.name, issue.issue_id)
      assert retval.empty?
    end

    it 'should call ensure_issue_label method with invalid issue' do
      user = create(:user)

      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email } } )

      issue = create(:issue,:github_issue)

      issue_label = create(:issue_label, :github_label)

      ght.stubs(:ensure_issue).returns nil
      ght.expects(:warn).returns("Could not find issue #{user.name_email}/#{repo.name} -> #{issue.issue_id} to assign label #{issue_label.name}")

      retval = ght.ensure_issue_label(user.name_email, repo.name, issue.issue_id, issue_label.name)
      refute retval
    end

    it 'should call ensure_issue_label method with invalid issue_label' do
      user = create(:user)

      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email } } )

      issue = create(:issue,:github_issue)

      issue_label = create(:issue_label, :github_label)

      ght.stubs(:ensure_issue).returns issue
      ght.stubs(:ensure_repo_label).returns nil
      ght.expects(:warn).returns("Could not find repo label #{user.name_email}/#{repo.name} -> #{issue_label.name}")

      retval = ght.ensure_issue_label(user.name_email, repo.name, issue.issue_id, issue_label.name)
      refute retval
    end

    it 'should call ensure_issue_label method with saved label returns []' do
      user = create(:user, db_obj: ght.db)

      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email }, db_obj: ght.db } )

      repo_label = create(:repo_label,
                { repo_id: repo.id, name: repo.name, db_obj: ght.db})
      commit = create(:sha, :github_commit, {project_id: repo.id, committer_id: user.id,
          author: user,
          committer: user,
          commit:  { :comment_count => 0, :author => user, :committer => user},
          parents: [], db_obj: ght.db} )
      pull_request = create(:pull_request, :github_pr, {base_repo_id: repo.id,
          base_commit_id: commit.id, db_obj: ght.db })
      issue = create(:issue,:github_issue,
              {repo_id: repo.id, assignee_id: user.id, db_obj: ght.db})
      issue_label = create(:issue_label, :github_label,
      {label_id: repo_label.id, issue_id: issue.id, name: repo.name,
        db_obj: ght.db})

      issue.pull_request = nil

      ght.stubs(:retrieve_issue).returns(issue)
      ght.stubs(:retrieve_issue_labels).returns ([issue_label])
      ght.stubs(:retrieve_issue_label).returns issue_label
      ght.stubs(:retrieve_repo_label).returns repo_label
      ght.expects(:debug)
        .returns("Issue label #{issue_label.name} to issue #{user.name_email}/#{repo.name} -> #{issue_label.issue_id} exists")
        .at_least_once

      retval = ght.ensure_issue_label(user.name_email, repo.name, issue.issue_id, issue_label.name)
      assert retval
      assert retval[:label_id].must_equal(issue_label.label_id)
    end

    it 'should call ensure_issue_labels method with invalid issue' do
      user = create(:user)

      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email } } )

      issue = create(:issue,:github_issue)
      ght.stubs(:ensure_issue).returns nil
      ght.expects(:warn).returns("Could not find issue #{user.name_email}/#{repo.name} -> #{issue.id} for retrieving labels")

      retval = ght.ensure_issue_labels(user.name_email, repo.name, issue.issue_id)
      refute retval
    end
  end
end
