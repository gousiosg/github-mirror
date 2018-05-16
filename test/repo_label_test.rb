require 'test_helper'

class GhtRepoLabelTest

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

   it 'should not be able to find repo_label' do
     user = create(:user, db_obj: @db)
     repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
     @ght.stubs(:retrieve_repo).returns(repo)
     @ght.stubs(:retrieve_repo_label).returns(nil)
     @ght.expects(:warn).returns("Could not retrieve repo_label #{user.name_email}/#{repo.name} -> master")

     retval = @ght.ensure_repo_label(user.name_email, repo.name, 'master')
     refute retval   
   end

   it 'should call ensure_repo_label with unsaved user and repo' do
     user = create(:user)
     repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
     @ght.stubs(:ensure_repo).returns(nil)
     @ght.expects(:warn).returns("Could not find #{user.name_email}/#{repo.name} for retrieving label master")

     retval = @ght.ensure_repo_label(user.name_email, repo.name, 'master')
     refute retval 
   end

   it 'should call ensure_repo_label' do
    user = create(:user, db_obj: @db)
    repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
    @ght.stubs(:retrieve_repo).returns(repo)
    @ght.stubs(:retrieve_repo_label).returns(['master'])
    
    retval = @ght.ensure_repo_label(user.name_email, repo.name, 'master')
    assert retval && retval[:name] == 'master'
   end
   
   it 'should call ensure_labels method with invalid repo' do
    user = create(:user)
    repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
    @ght.stubs(:ensure_user).returns user
    @ght.stubs(:retrieve_repo).returns(nil)
    @ght.expects(:warn)
        .returns("Could not find #{user.name_email}/#{repo.name} for retrieving issue labels")
        .at_least_once
        
    retval = @ght.ensure_labels(user.name_email, repo.name)
    refute retval 
   end

   it 'should call ensure_labels method with saved user and repo' do
    user = create(:user, db_obj: @db)
    repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )

    @ght.stubs(:retrieve_repo).returns(repo)
    @ght.stubs(:retrieve_repo_labels).returns(['master'])
    @ght.stubs(:ensure_repo_label).returns('master')
    
    retval = @ght.ensure_labels(user.name_email, repo.name)
    assert retval && retval.first == 'master'
   end

   it 'should call ensure_repo_label with unsaved user and repo and label' do
    user = create(:user)
    repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
    @ght.stubs(:retrieve_user_byemail).returns(user)
    @ght.stubs(:retrieve_repo).returns(nil)
    @ght.stubs(:retrieve_repo_label).returns(['master'])
    retval = @ght.ensure_repo_label(user.name_email, repo.name, 'master')
    refute retval 
   end
  end
end