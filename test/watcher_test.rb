require 'test_helper'

class GhtWatcherTest < Minitest::Test
 describe 'test configuration and helper methods' do
   before do
     session = 1
     @ght = GHTorrent::Mirror.new(session)
     @db = @ght.db
   end

   it 'should call the ensure_watchers method without a saved watcher' do
    user = create(:user, db_obj: @db)
    watcher_user = create(:user, db_obj: @db)
    repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, db_obj: @ght.db } )

    # @ght.stubs(:retrieve_repo).returns repo    
    @ght.stubs(:retrieve_watchers).returns [watcher_user]
    @ght.stubs(:retrieve_watcher).returns watcher_user

    retval = @ght.ensure_watchers(user.name_email, repo.name)
    assert retval[0][:user_id] == watcher_user.id
   end

   it 'should call the ensure_watchers method with a saved watcher; returns []' do
    user = create(:user, db_obj: @db)
    watcher_user = create(:user, db_obj: @db)
    watcher_user.login = watcher_user.name_email
    repo = create(:repo, { owner_id: user.id, db_obj: @db})
    watcher = create(:watcher, {repo_id: repo.id, user_id: watcher_user.id, db_obj: @db})

    @ght.stubs(:retrieve_watchers).returns [watcher_user]
    @ght.stubs(:retrieve_watcher).returns watcher_user

    retval = @ght.ensure_watchers(user.name_email, repo.name)
    assert retval.empty?
   end

   it 'should call the ensure_watchers method without a saved repository' do
    user = create(:user, db_obj: @db)
    watcher_user = create(:user, db_obj: @db)
    watcher_user.login = watcher_user.name_email
    repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} } )
 
    @ght.stubs(:retrieve_repo).returns(nil)

    retval = @ght.ensure_watchers(user.name_email, repo.name)
    refute retval
   end
   
   it 'should call the ensure_watcher method without a saved repository' do
    user = create(:user, db_obj: @db)
    watcher_user = create(:user, db_obj: @db)
    watcher_user.login = watcher_user.name_email
    repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} } )
 
    @ght.stubs(:retrieve_watchers).returns [watcher_user]
    @ght.stubs(:retrieve_watcher).returns nil
    @ght.stubs(:retrieve_repo).returns(nil)
  
    retval = @ght.ensure_watcher(user.name_email, repo.name, watcher_user.name_email, DateTime.now)
    refute retval
   end

   it 'should call the ensure_watcher method without a saved repository' do
    user = create(:user, db_obj: @db)
    watcher_user = create(:user, db_obj: @db)
    watcher_user.login = watcher_user.name_email
    repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} } )
 
    @ght.stubs(:retrieve_watchers).returns [watcher_user]
    @ght.stubs(:retrieve_watcher).returns nil
    @ght.stubs(:retrieve_repo).returns(repo)
  
    retval = @ght.ensure_watcher(user.name_email, repo.name, watcher_user.name_email, DateTime.now)
    refute retval
   end
 end
end
   