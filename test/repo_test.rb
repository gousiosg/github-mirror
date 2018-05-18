require 'test_helper'

class GhtRepoTest

  describe 'test the user repo methods' do
    around do | test | 
      ght_trx do
        test.call
      end
    end

    before do
      @ght = ght
      @db = db
    end
   
    it 'should return a repo given a user and repo' do
     user = create(:user, db_obj: @db)
     repo = create(:project, { owner_id: user.id, db_obj: @db })
     
     assert repo.owner_id = user.id
     repo = @ght.ensure_repo(user.name_email, repo.name)
     
     assert repo
    end
 
    it 'should not return a repo given a user and bad repo' do
     user = create(:user, db_obj: @db)
     repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} } )
     
     @ght.stubs(:retrieve_repo).returns(nil)
     @ght.expects(:warn).returns("Could not retrieve repo #{user.name_email}/#{repo.name}")

     repo = @ght.ensure_repo(user.name_email, repo.name)
     assert repo.nil?
    end
 
    it 'should not return a repo given a bad user' do
      user = create(:user)
      repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} } )
      @ght.stubs(:ensure_user).returns nil
      @ght.expects(:warn).returns("Could not find user #{user}")
      
      repo = @ght.ensure_repo(user.name_email, repo.name)
      assert repo.nil?
    end
 
    it 'should return a repo given a user and invalid repo will add repo to db' do
     user = create(:user, db_obj: @db)
     repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} })
     
     @ght.stubs(:retrieve_repo).returns(repo)
     @ght.stubs(:ensure_fork_point).returns nil
 
     retval = @ght.ensure_repo(user.name_email, repo.name)
     assert retval
 
     projects = @db[:projects]
     project = projects.where(:id => retval[:id]).first
     assert project && project[:url] == repo.url && project[:name] == repo.name
    end
 
    it 'should return a repo that has a parent repo' do
     user = create(:user, db_obj: @db)
     parent_user = create(:user, db_obj: @db)
     parent_repo = create(:repo, { owner_id: parent_user.id, db_obj: @db })
 
     repo = create(:repo, :github_project, { owner_id: user.id, 
                    owner: {'login' => user.login}, 
                   parent: {'name'  => parent_repo.name, 'owner' => {'login' =>parent_user.login}} } )
 
     @ght.stubs(:retrieve_repo).returns(repo)
 
     db_repo = @ght.ensure_repo(user.name_email, repo.name)
     assert db_repo[:url].must_equal repo.url
    end
 
    it 'should return a repo that has changed ownership' do
     user = create(:user, db_obj: @db)
     parent_user = create(:user, db_obj: @db)
     parent_repo = create(:repo, { owner_id: parent_user.id, db_obj: @db })
 
     repo = create(:repo, :github_project, { owner_id: user.id, 
                    owner: {'login' => parent_user.login}, 
                   parent: {'name'  => parent_repo.name, 'owner' => {'login' =>parent_user.login}} } )
 
     @ght.stubs(:retrieve_repo).returns(repo)
     @ght.stubs(:ensure_fork_point).returns nil
     db_repo = @ght.ensure_repo(user.name_email, repo.name)
     assert db_repo[:url].must_equal repo.url
    end
 
    it 'should return nil from ensure_repo_commits if no project' do
      user = create(:user, db_obj: @db)
      repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} })
      @ght.stubs(:ensure_repo).returns nil
      @ght.expects(:warn).returns("Repo #{user.name}/#{repo.name} does not exist")

      retval = @ght.ensure_repo_commit(user.name, repo.name, 0)
      assert retval.nil?
    end
 
    it 'should not return nil from ensure_repo_commits if project exists' do
      user = create(:user, db_obj: @db)
      repo = create(:repo, { owner_id: user.id, db_obj: @db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,  
                       commit:  { :comment_count.to_s => 3},
                       parents: [],
                       db_obj: @db})
  
      @ght.stubs(:ensure_commit).returns(commit)                
      @ght.stubs(:retrieve_commit).returns(commit)
      @ght.stubs(:retrieve_commit_comments).returns []
      sha = commit.sha
  
      retval = @ght.ensure_repo_commit(user.name_email, repo.name, sha)
      assert retval 
      assert retval[:commit_id].must_equal commit[:id]
  
      # run 2nd time so that the project_commits exist in table
      retval = @ght.ensure_repo_commit(user.name_email, repo.name, sha)
      assert retval 
      assert retval[:commit_id].must_equal commit[:id]
    end
    
    it 'should ensure the repo returns languague info and saves to the db' do
      user = create(:user, db_obj: @db)
      repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
      @ght.stubs(:retrieve_repo).returns(repo)
      @ght.stubs(:retrieve_languages).returns({"Ruby"=>35941, "HTML"=>6085, "JavaScript"=>2239, "CSS"=>1728})
  
      @ght.ensure_languages(user.name_email, repo.name)
      
      repo_in_db = @ght.ensure_repo(user.name_email, repo.name)
      assert @db[:project_languages].where(:project_id => repo_in_db[:id]).count.must_equal 4
    end
 
    it 'calls ensure_repo_recursive - if all stages are successful returns true' do
      @ght.stages.each do |stage|
        @ght.stubs(stage.to_sym).returns(true)
      end
      retval = @ght.ensure_repo_recursive('msk999', 'fake_repo')
      assert retval
    end
 
    it 'calls ensure_repo_recursive - if one stage is not successful returns false' do
      @ght.stubs(@ght.stages[0].to_sym).returns(nil)
      @ght.expects(:warn).returns("Stage #{@ght.stages[0]} returned nil, stopping recursive retrieval")
      retval = @ght.ensure_repo_recursive('msk999', 'fake_repo')
      refute retval
    end
 
    it 'should create persist a fake project' do
      user = create(:user, db_obj: @db)
      project = create(:project, :github_project, 
        { owner_id: user.id, owner: {'login' => user.login}, db_obj: @db } ) 
      assert project
      saved_project = @db[:projects].where(id: project.id).first
      saved_project[:name].must_equal project.name 
    end
 
    it 'should not persist a fake user' do
      user = create(:user) 
      assert user
      @db[:users].where(login: user.login).count.must_equal 0
    end
  end
end