require 'test_helper'

class GhtorrentTest
  describe 'test configuration and helper methods' do
    before do
     @ght = ght
     @db = db
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
      assert @db.tables.any?
    end

    it 'should test the persister method' do
      persister = @ght.persister
      assert persister

      # reset persister to nil
      @ght.stubs(:persister).returns nil
      assert @ght.persister.nil?
    end

    it 'should test the stages method' do
      stages = @ght.stages
      assert stages.length > 0
    end
  end
end
