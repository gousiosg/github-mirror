require 'test_helper'

describe 'GhtFork' do
  describe 'ghtorrent fork tests' do
    run_tests_in_transaction

    it 'should call ensure_fork method with missing repo' do
      user = create(:user, db_obj: db)
      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email }, forked_from: Faker::Number.number(2) } )

      ght.stubs(:retrieve_fork).returns nil
      ght.expects(:warn).returns("Could not retrieve fork #{user.name_email}/#{repo.name} -> #{repo.forked_from}")

      retval = ght.ensure_fork(user.name_email, repo.name, repo.forked_from)
      refute retval
    end

    it 'should call ensure_fork method with existing repo missing fork name' do
      user = create(:user, db_obj: db)
      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email },
          db_obj: db })
      ght.stubs(:retrieve_fork).returns repo

      fork_owner = repo.url.split(/\//)[4]

      ght.expects(:info).returns("Added fork #{fork_owner}/#{repo.name} of #{user.name_email }/#{repo.name}")
      retval = ght.ensure_fork(user.name_email, repo.name, repo.forked_from)
      assert retval
    end

    it 'should call ensure_fork without existing fork' do
      user = create(:user, db_obj: db)
      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email },
          db_obj: db })
      ght.stubs(:retrieve_fork).returns repo
      ght.stubs(:ensure_repo).returns nil

      fork_owner = repo.url.split(/\//)[4]
      ght.expects(:warn).returns("Could not add #{fork_owner}/#{repo.name} as fork of #{user.name_email}/#{repo.name}")

      retval = ght.ensure_fork(user.name_email, repo.name, repo.forked_from)
      refute retval
    end

    it 'should call ensure-forks method with missing repo' do
      user = create(:user)
      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email }, forked_from: Faker::Number.number(2)})
      ght.stubs(:ensure_repo).returns nil
      ght.expects(:warn).returns("Could not find repo #{user.name_email}/#{repo.name} for retrieving forks")
      retval = ght.ensure_forks(user.name_email, repo.name)
      refute retval
    end

    it 'should call ensure_forks method with existing repo missing fork name' do
      user = create(:user, db_obj: db)
      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email },
          db_obj: db })
      ght.stubs(:retrieve_fork).returns repo
      ght.stubs(:retrieve_forks).returns([repo])

      fork_owner = repo.url.split(/\//)[4]

      ght.expects(:info).returns("Added fork #{fork_owner}/#{repo.name} of #{user.name_email }/#{repo.name}")
      retval = ght.ensure_forks(user.name_email, repo.name)
      assert retval
    end

    it 'should call ensure_forks method with existing repo fork name' do
      user = create(:user, db_obj: db)
      fork_repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email },
          db_obj: db })

      repo = create(:repo, :github_project, { owner_id: user.id,
          owner: { 'login' => user.name_email }, forked_from: fork_repo.id,
          db_obj: db })

      ght.stubs(:retrieve_fork).returns repo
      ght.stubs(:retrieve_forks).returns([repo])

      retval = ght.ensure_forks(user.name_email, fork_repo.name)
      assert retval
    end
  end
end
