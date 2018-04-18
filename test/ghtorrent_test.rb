require 'test_helper'
include FactoryGirl::Syntax::Methods

class GhtorrentTest < Minitest::Test
describe 'ghtorrent::mirror module' do
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

  it 'should test GHTorrent::Mirrormax method' do
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

   it 'should test the ensure_user method' do
    users = @ght.db[:users]
    user = users.where(:login => 'msk999').first
    returned_user = @ght.ensure_user(user[:login], false, false) 
    assert returned_user == user
   end
   
   it 'ensure_user method should not return a user if given a bad email' do
    assert @ght.ensure_user('zzz@asldkf.com').nil? 
   end
   
   it 'ensure_user should find correct user if given a name and email' do
    users = @ght.db[:users]
    user = users.where(:login => 'msk999').first
    GHTorrent::Mirror.any_instance.stubs(:ensure_user_byemail).returns(user) 
    returned_user = @ght.ensure_user("#{user[:login]}<msk999@xyz.com>", false, false) 
    assert returned_user == user
   end

   it 'ensure_user should not find a user if given a bad user name only' do
    returned_user = @ght.ensure_user("~999~$", false, false) 
    assert returned_user.nil?
   end
   
   it 'should return a user given an email and user' do
    email = 'matthew.krasnick@gmail.com'
    returned_user = @ght.ensure_user_byemail(email, 'msk999')
    assert returned_user[:email] == email
   end

   it 'should return a user given a bad email and user' do
    fake_email = 'matthew~1@gmail.com'
    returned_user = @ght.ensure_user_byemail(fake_email, 'msk999')
    assert returned_user
    assert returned_user[:email] == fake_email 
    assert returned_user[:name] == 'msk999'
  
    users = @ght.db[:users]
    users.where(:email => fake_email).delete 
   end

   it 'should return a repo given a user and repo' do
    repo = @ght.ensure_repo('msk999', 'Subscribem')
    assert repo
   end

   it 'should not return a repo given a user and bad repo' do
    repo = @ght.ensure_repo('msk999', 'Subscribem-z')
    assert repo.nil?
   end
   it 'should not return a repo given a bad user' do
    repo = @ght.ensure_repo('msk999z', 'Subscribem')
    assert repo.nil?
   end

   it 'should return a repo given a user and missing repo' do
    user_id = @ght.ensure_user('msk999', false, false)[:id]
    repos = @ght.db[:projects]  
    # change the name of a valid repo so it can't be found
    repos.where(:owner_id => user_id, :name => 'Subscribem').update(:name => 'Fake_repo')
    repo = @ght.ensure_repo('msk999', 'Subscribem')
    assert repo
   end

   it 'should ensure the repo returns languague info' do
    langs = @ght.ensure_languages('msk999', 'Subscribem')
    assert langs
   end

   it 'should ensure the invalid repo does not return languague info' do
    langs = @ght.ensure_languages('msk999', 'fake_repo')
    assert langs.nil?
   end

   it 'calls ensure_repo_recursive - not sure what this does' do
      retval = @ght.ensure_repo_recursive('msk999', 'Subscribem')
      assert retval
   end

   it 'calls ensure_commit method' do
     users = @ght.db[:users]
     user = users.where(:login => 'msk999').first
     project_id = @ght.db[:projects].where(:owner_id => user[:id]).first[:id]
     sha = @ght.db[:commits].where(:project_id => project_id).first[:sha]
     
     commit = @ght.ensure_commit('Subscribem', sha, 'msk999')
     assert commit[:sha] == sha
     assert commit[:project_id] == project_id
   end

  it ' calls ensure_commits method' do
    users = @ght.db[:users]
    user = users.where(:login => 'msk999').first
    project_id = @ght.db[:projects].where(:owner_id => user[:id]).first[:id]
    sha = @ght.db[:commits].where(:project_id => project_id).first[:sha]
    
    commit = @ght.ensure_commits('msk999', 'Subscribem', sha: sha, return_retrieved: true, fork_all: true)
    assert commit[0][:sha] == sha
  end

   it 'should create persist a fake user' do
      user = create(:user, db_obj: @ght.db) 
      assert user
      saved_user = @ght.db[:users].where(id: user.id).first
      saved_user[:name].must_equal user.name 
   end

   it 'should not persist a fake user' do
      user = create(:user) 
      assert user
      @ght.db[:users].where(login: user.login).count.must_equal 0
   end
   
   it 'tries to store an invalid commit - need to put this one into transaction' do
    users = @ght.db[:users]
    user = users.where(:login => 'msk999').first
    project_id = @ght.db[:projects].where(:owner_id => user[:id]).first[:id]
    sha = @ght.db[:commits].where(:project_id => project_id).first[:sha]
    commit = @ght.db[:commits].where(:sha => '10').first 
    commit = @ght.retrieve_commit('Subscribem', sha, 'msk999')

    # make commit sha invalid
    commit['sha'] = '10'
    retval = @ght.store_commit(commit, 'subscribem', 'msk999')
    assert retval
   end

   it 'calls ensure_user_follower method' do
    retval = @ght.ensure_user_follower('msk999', 'msk999')
   end
  end

  # it 'should run if arguments are given' do
  #   ARGV[0] = 'msk999'
  #   ARGV << 'Subscribem'
  #   GHTRetrieveRepo.run(ARGV)
  # end
end