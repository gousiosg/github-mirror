require 'test_helper'

describe 'GhtRetrieveRepo' do
  it 'test_it_does_something_useful' do
    assert true # this will result in a failure
  end 

  it 'test_load_ght_retrieve_repo' do
    ght = GHTRetrieveRepo.new
    err = ->{ ght.go() }.must_raise RuntimeError
    err.message.must_match /Unimplemented/
  end
    
  it 'test_load_ghtorrent.new()' do
    ght = GHTRetrieveRepo.new
    err = -> { ght.validate }.must_raise RuntimeError
    err.message.must_match /Unimplemented/
  end
end

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
    user = users.where(:name => 'matthew').first
    byebug
    @ght.ensure_user(user)
   end

  # it 'should run if arguments are given' do
  #   ARGV[0] = 'msk999'
  #   ARGV << 'Subscribem'
  #   GHTRetrieveRepo.run(ARGV)
  # end
end