require 'test_helper'

class GhtorrentTest
  describe 'test configuration and helper methods' do
    before do
     session = 1
     @ght = GHTorrent::Mirror.new(session)
    end
   
   it 'should be able to access configurations' do
     assert GHTorrent::ROUTEKEY_CREATE == "evt.CreateEvent"
     assert GHTorrent::ROUTEKEY_DELETE == "evt.DeleteEvent"
     assert GHTorrent::ROUTEKEY_DOWNLOAD == "evt.DownloadEvent"
     assert GHTorrent::ROUTEKEY_FOLLOW == "evt.FollowEvent"
     assert GHTorrent::ROUTEKEY_FORK == "evt.ForkEvent"
     assert GHTorrent::ROUTEKEY_FORK_APPLY == "evt.ForkApplyEvent"
     assert GHTorrent::ROUTEKEY_GIST == "evt.GistEvent"
     assert GHTorrent::ROUTEKEY_GOLLUM == "evt.GollumEvent"
     assert GHTorrent::ROUTEKEY_ISSUE_COMMENT == "evt.IssueCommentEvent"
     assert GHTorrent::ROUTEKEY_ISSUES == "evt.IssuesEvent"
     assert GHTorrent::ROUTEKEY_MEMBER == "evt.MemberEvent"
     assert GHTorrent::ROUTEKEY_PUBLIC == "evt.PublicEvent"
     assert GHTorrent::ROUTEKEY_PULL_REQUEST == "evt.PullRequestEvent"
     assert GHTorrent::ROUTEKEY_PULL_REQUEST_REVIEW_COMMENT == "evt.PullRequestReviewCommentEvent"
     assert GHTorrent::ROUTEKEY_PUSH == "evt.PushEvent"
     assert GHTorrent::ROUTEKEY_TEAM_ADD == "evt.TeamAddEvent"
     assert GHTorrent::ROUTEKEY_WATCH == "evt.WatchEvent"
     assert GHTorrent::ROUTEKEY_PROJECTS == "evt.projects"
     assert GHTorrent::ROUTEKEY_USERS == "evt.users"
   end
 
   it 'should test GHTorrent::Mirror.max method' do
     ght = GHTorrent::Mirror.new(1)
     assert ght.max(5,7) == 7
     assert ght.max(7,5) == 7
   end
 
   it 'should test is_valid_email(email) method' do
     assert @ght.is_valid_email('user@ghtorrent.com')
     refute @ght.is_valid_email('abc')
   end
 
   it 'should test the date method' do
     #  2018-04-10 01:18:00 +0000 
     sdate = DateTime.now.strftime("%Y-%m-%d %H:%M:%S %z")
     time_date = Time.parse(sdate)#.to_idt
     assert @ght.date(sdate) == time_date
     assert @ght.date(time_date) == time_date
   end
 
    it 'should test the boolean method' do
     assert @ght.boolean('true') == 1
     assert @ght.boolean('false') == 0 
     assert @ght.boolean(nil) == 0
    end
 
    it 'should test the db method' do
      assert @ght.db.tables.any?
      ## close the connection
      @ght.dispose
    end
 
    it 'should test the persister method' do
      persister = @ght.persister
      assert persister
    end
 
    it 'should test the stages method' do
      stages = @ght.stages
      assert stages.length > 0
    end
  end

  describe 'test the user repo methods' do
    before do
      session = 1
      @ght = GHTorrent::Mirror.new(session)
    end
   
    it 'should return a repo given a user and repo' do
     user = create(:user, db_obj: @ght.db)
     project = create(:project, { owner_id: user.id, db_obj: @ght.db })
     
     assert project.owner_id = user.id
     repo = @ght.ensure_repo(user.name_email, project.name)
     
     assert repo
    end
 
    it 'should not return a repo given a user and bad repo' do
     user = create(:user, db_obj: @ght.db)
     repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} } )
     
     @ght.stubs(:retrieve_repo).returns(nil)
     
     repo = @ght.ensure_repo(user.name_email, repo.name)
     assert repo.nil?
    end
 
    it 'should not return a repo given a bad user' do
     repo = @ght.ensure_repo('msk999z', 'Subscribem')
     assert repo.nil?
    end
 
    it 'should return a repo given a user and bogus repo will add repo to db' do
     user = create(:user, db_obj: @ght.db)
     repo = create(:repo, {owner_id: user.id, owner: {'login' => user.login} })
     
     @ght.stubs(:retrieve_repo).returns(repo)
     @ght.stubs(:ensure_fork_point).returns nil
 
     db_repo = @ght.ensure_repo(user.name_email, repo.name)
     assert db_repo
 
     projects = @ght.db[:projects]
     project = projects.where(:id => db_repo[:id]).first
     assert project && project[:url] == repo.url && project[:name] == repo.name
    end
 
    it 'should return a repo that has a parent repo' do
     user = create(:user, db_obj: @ght.db)
     parent_user = create(:user, db_obj: @ght.db)
     parent_repo = create(:repo, { owner_id: parent_user.id, db_obj: @ght.db })
 
     repo = create(:repo, :github_project, { owner_id: user.id, 
                    owner: {'login' => user.login}, 
                   parent: {'name'  => parent_repo.name, 'owner' => {'login' =>parent_user.login}} } )
 
     @ght.stubs(:retrieve_repo).returns(repo)
 
     db_repo = @ght.ensure_repo(user.name_email, repo.name)
     assert db_repo[:url].must_equal repo.url
    end
 
    it 'should return a repo that has changed ownership' do
     user = create(:user, db_obj: @ght.db)
     parent_user = create(:user, db_obj: @ght.db)
     parent_repo = create(:repo, { owner_id: parent_user.id, db_obj: @ght.db })
 
     repo = create(:repo, :github_project, { owner_id: user.id, 
                    owner: {'login' => parent_user.login}, 
                   parent: {'name'  => parent_repo.name, 'owner' => {'login' =>parent_user.login}} } )
 
     @ght.stubs(:retrieve_repo).returns(repo)
     @ght.stubs(:ensure_fork_point).returns nil
     db_repo = @ght.ensure_repo(user.name_email, repo.name)
     assert db_repo[:url].must_equal repo.url
    end
 
    it 'should return nil from ensure_repo_commits if no project' do
     retval = @ght.ensure_repo_commit('msk999', 'subscribem-z', 'abc')
     assert retval.nil?
    end
 
    it 'should call ensure_repo_label' do
     user = create(:user, db_obj: @ght.db)
     repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
     @ght.stubs(:retrieve_repo).returns(repo)
     @ght.stubs(:retrieve_repo_label).returns(['master'])
     
     retval = @ght.ensure_repo_label(user.name_email, repo.name, 'master')
     assert retval && retval[:name] == 'master'
    end
 
    it 'should not be able to find repo_label' do
     user = create(:user, db_obj: @ght.db)
     repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
     @ght.stubs(:retrieve_repo).returns(repo)
     @ght.stubs(:retrieve_repo_label).returns(nil)
     retval = @ght.ensure_repo_label(user.name_email, repo.name, 'master')
 
     refute retval   
    end
 
    it 'should call ensure_repo_label with unsaved user and repo' do
     user = create(:user)
     repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
     @ght.stubs(:retrieve_repo).returns(nil)
     @ght.stubs(:retrieve_repo_label).returns(['master'])
     
     retval = @ght.ensure_repo_label(user.name_email, repo.name, 'master')
     refute retval 
    end
    
    it 'should call ensure_labels method' do
     user = create(:user)
     repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
     @ght.stubs(:retrieve_repo).returns(nil)
     @ght.stubs(:retrieve_repo_label).returns(['master'])
     
     retval = @ght.ensure_labels(user.name_email, repo.name)
     refute retval 
    end
 
    it 'should call ensure_labels method with saved user and repo' do
     user = create(:user, db_obj: @ght.db)
     repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
 
     @ght.stubs(:retrieve_repo).returns(repo)
     @ght.stubs(:retrieve_repo_labels).returns(['master'])
     @ght.stubs(:ensure_repo_label).returns('master')
     
     retval = @ght.ensure_labels(user.name_email, repo.name)
     assert retval && retval.first == 'master'
    end
 
    it 'should call ensure_repo_label with unsaved user and repo' do
     user = create(:user)
     repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
     @ght.stubs(:retrieve_repo).returns(nil)
     @ght.stubs(:retrieve_repo_label).returns(['master'])
     
     retval = @ght.ensure_repo_label(user.name_email, repo.name, 'master')
     refute retval 
    end
 
    it 'should not return nil from ensure_repo_commits if project exists' do
      user = create(:user, db_obj: @ght.db)
      repo = create(:repo, { owner_id: user.id, db_obj: @ght.db})
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,  
                       commit:  { :comment_count.to_s => 3},
                       parents: [],
                       db_obj: @ght.db})
  
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
      user = create(:user, db_obj: @ght.db)
      repo = create(:project, :github_project, { owner_id: user.id, owner: {'login' => user.login} } )
      @ght.stubs(:retrieve_repo).returns(repo)
      @ght.stubs(:retrieve_languages).returns({"Ruby"=>35941, "HTML"=>6085, "JavaScript"=>2239, "CSS"=>1728})
  
      langs = @ght.ensure_languages(user.name_email, repo.name)
      
      repo_in_db = @ght.ensure_repo(user.name_email, repo.name)
      assert @ght.db[:project_languages].where(:project_id => repo_in_db[:id]).count.must_equal 4
    end
 
    it 'calls ensure_repo_recursive - if all stages are successful returns true' do
      @ght.stages.each do |stage|
        @ght.stubs(stage.to_sym).returns(true)
      end
      retval = @ght.ensure_repo_recursive('msk999', 'fake_repo')
      assert retval
    end
 
    it 'calls ensure_repo_recursive - if one stage is not successful returns false' do
      @ght.stubs(@ght.stages[0].to_sym).returns(false)
      
      retval = @ght.ensure_repo_recursive('msk999', 'fake_repo')
      refute retval
    end
 
    it 'should create persist a fake project' do
      project = create(:project, db_obj: @ght.db) 
      assert project
      saved_project = @ght.db[:projects].where(id: project.id).first
      saved_project[:name].must_equal project.name 
    end
 
    it 'should not persist a fake user' do
      user = create(:user) 
      assert user
      @ght.db[:users].where(login: user.login).count.must_equal 0
    end
    
    it 'calls ensure_user_follower method' do
      user = create(:user)
      retval = @ght.ensure_user_follower(user.name, user.name)
    end
 
    it 'calls ensure_user_follower method with real users' do
      followed = create(:user, db_obj: @ght.db )
      follower_user = create(:user, db_obj: @ght.db )
      follower = create(:follower, {follower_id: follower_user.id, user_id: followed.id, db_obj: @ght.db})
  
      retval = @ght.ensure_user_follower(followed.name_email, follower_user.name_email)
      assert retval 
      assert retval[:follower_id].must_equal follower.follower_id
    end
 
    it 'calls ensure_user_follower method without saved follower' do
      followed = create(:user, db_obj: @ght.db )
      follower_user = create(:user)
      follower = create(:follower, {follower_id: follower_user.id, user_id: followed.id})
  
      @ght.stubs(:retrieve_user_follower).returns follower
  
      retval = @ght.ensure_user_follower(followed.name_email, follower_user.name_email)
      assert retval 
      assert retval[:user_id].must_equal followed.id
    end
 
    it 'calls ensure_user_follower method updates date_created' do
      followed = create(:user, db_obj: @ght.db )
      follower_user = create(:user)
      follower = create(:follower, {follower_id: follower_user.id, user_id: followed.id})
  
      @ght.stubs(:retrieve_user_follower).returns follower
      
      time_stamp = (Date.today + 1).strftime('%FT%T %z')
      
      refute follower.created_at == time_stamp
      retval = @ght.ensure_user_follower(followed.name_email, follower_user.name_email, time_stamp)
      assert retval[:created_at].strftime('%FT%T %z').must_equal time_stamp 
    end
 
 
    it 'calls ensure_user_follower method without any follower' do
      followed = create(:user, db_obj: @ght.db )
      follower_user = create(:user)
  
      @ght.stubs(:retrieve_user_follower).returns nil
      @ght.stubs(:retrieve_user_byemail).returns follower_user
      @ght.expects(:warn).returns("Could not retrieve follower #{follower_user.name_email} for #{followed.name_email}")
      
      retval = @ght.ensure_user_follower(followed.name_email, follower_user.name_email, DateTime.now.strftime('%FT%T%:z'))
      refute retval
    end
 
    it 'calls ensure_user_followers(followed) method' do
      followed = create(:user, db_obj: @ght.db )
      follower_user = create(:user, db_obj: @ght.db )
      follower = create(:follower, {follower_id: follower_user.id, user_id: followed.id, db_obj: @ght.db})
      @ght.stubs(:retrieve_user_followers).returns [ 'follows' => followed ]
  
      retval = @ght.ensure_user_followers(followed.name_email)
      assert retval.empty?
    end
 
    it 'should call ensure_user_following method' do
      following = create(:user, db_obj: @ght.db )
      follower_user = create(:user, db_obj: @ght.db )
      follower = create(:follower, {follower_id: following.id, user_id: following.id, db_obj: @ght.db})
      @ght.stubs(:retrieve_user_following).returns [ 'follows' => following ]
  
      retval = @ght.ensure_user_following(following.name_email)
      assert retval.empty?
    end
 
    it 'should call the ensure orgs method with a regular user' do
     user = create(:user, db_obj: @ght.db)
     @ght.stubs(:retrieve_orgs).returns([user])
     retval = @ght.ensure_orgs(user.name)
     assert retval.empty?
    end
 
    it 'should call the ensure orgs method with an organization' do
      fake_name_login = Faker::Name.first_name
      user = create(:user, {name: fake_name_login, login: fake_name_login, type: 'org', db_obj: @ght.db})
      org_member = create(:user,db_obj: @ght.db)
      @ght.stubs(:retrieve_orgs).returns([user])
      @ght.stubs(:retrieve_org_members).returns([user])
      @ght.stubs(:ensure_user).returns(user)
      retval = @ght.ensure_orgs(user)
      assert retval && retval[0][:user_id] == user.id
   end
  end
end