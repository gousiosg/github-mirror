require 'test_helper'
require 'sequel/adapters/mysql2'

class TestRetriever
  attr_writer :extra_commits

  include GHTorrent::EventProcessing

  def ght
    @ght ||= TestGht.new
  end

  def persister
    @persister ||= OpenStruct.new
  end

  def retrieve_commits(_repo, _last_sha, _owner, _pages)
    if @attempted_once
      @attempted_once = false
      [@extra_commits.last]
    else
      @attempted_once = true
      @extra_commits
    end
  end
end

class TestGht < OpenStruct
  def db
    @db ||= GHTorrent::Mirror.new(config).db
  end

  def transaction
    yield
  end
end

describe 'EventProcessing' do
  let(:retriever) { TestRetriever.new }

  # FIXME: EventProcessing is expecting url in the following format:
  # https://api.github.com/repos/user/repo/commits/<sha>
  # However, the events api returns commits.url in the following format:
  # https://github.com/user/repo/commit/<sha>
  # https://developer.github.com/v3/activity/events/types/#pushevent
  describe 'PushEvent' do
    it 'must call ensure_commit on each commit' do
      shas = Array.new(3) { Faker::Number.hexadecimal(40) }
      commits = shas.map { |sha| { 'url' => "https://api.github.com/repos/hamster/hello/commits/#{sha}" } }
      data = { 'payload' => { 'commits' => commits } }
      shas.each do |sha|
        retriever.ght.expects(:ensure_commit).with('hello', sha, 'hamster')
      end
      retriever.PushEvent(data)
    end

    # FIXME: Fix undefined variable sha in source.
    it 'must raise exception if url pattern does not match' do
      shas = Array.new(1) { Faker::Number.hexadecimal(40) }
      commits = shas.map { |sha| { 'url' => "https://api.github.com/repos/hamster/hello/commits/blah/#{sha}" } }
      data = { 'payload' => { 'commits' => commits } }
      retriever.ght.expects(:ensure_commit).never
      -> { retriever.PushEvent(data) }.must_raise(NameError)
    end

    it 'must call ensure_commit on all commits' do
      shas = Array.new(20) { Faker::Number.hexadecimal(40) }
      commits = shas.map { |sha| { 'sha' => sha,
                                   'url' => "https://api.github.com/repos/hamster/hello/commits/#{sha}" } }
      extra_shas = Array.new(2) { Faker::Number.hexadecimal(40) }
      extra_commits = extra_shas.map { |sha| { 'sha' => sha,
                                               'url' => "https://api.github.com/repos/hamster/hello/commits/#{sha}" } }
      data = { 'payload' => { 'commits' => commits },
               'repo' => { 'name' => 'hamster/hello' } }

      retriever.extra_commits = extra_commits
      (shas + extra_shas).each do |sha|
        retriever.ght.expects(:ensure_commit).with('hello', sha, 'hamster')
      end
      retriever.PushEvent(data)
    end

    it 'wont call ensure_commit on extra commits if they exist in db' do
      shas = Array.new(20) { Faker::Number.hexadecimal(40) }
      commits = shas.map { |sha| { 'sha' => sha,
                                   'url' => "https://api.github.com/repos/hamster/hello/commits/#{sha}" } }
      extra_shas = Array.new(2) { Faker::Number.hexadecimal(40) }
      extra_commits = extra_shas.map { |sha| { 'sha' => sha,
                                               'url' => "https://api.github.com/repos/hamster/hello/commits/#{sha}" } }
      data = { 'payload' => { 'commits' => commits },
               'repo' => { 'name' => 'hamster/hello' } }
      retriever.extra_commits = extra_commits
      Sequel::Mysql2::Dataset.any_instance.expects(:all).returns([1])
      shas.each do |sha|
        retriever.ght.expects(:ensure_commit).with('hello', sha, 'hamster')
      end
      retriever.PushEvent(data)
    end
  end

  describe 'WatchEvent' do
    it 'must call ensure_watcher for passed data' do
      created_at = Faker::Time.backward
      data = { 'repo' => { 'name' => 'hamster/hello' },
               'actor' => { 'id' => 1, 'login' => 'hamster', 'gravatar_id' => '',
                            'avatar_url' => Faker::Internet.url,
                            'url' => 'https://api.github.com/users/hamster' },
               'created_at' => created_at }
      retriever.persister.expects(:upsert)
      retriever.ght.expects(:ensure_user).with('hamster', false, false).returns(type: 'Event')
      retriever.ght.expects(:ensure_watcher).with('hamster', 'hello', 'hamster', created_at)
      retriever.WatchEvent(data)
    end
  end

  # FIXME: event is discontinued: https://developer.github.com/v3/activity/events/types/#followevent
  describe 'FollowEvent' do
    it 'must call ensure_user_follower with appropriate data' do
      created_at = Faker::Time.backward
      data = { 'payload' => { 'target' => { 'login' => 'followed_user' } },
               'actor' => { 'login' => 'follower' },
               'created_at' => created_at }
      retriever.ght.expects(:ensure_user_follower).with('followed_user', 'follower', created_at)
      retriever.FollowEvent(data)
    end
  end

  describe 'MemberEvent' do
    let(:created_at) { Faker::Time.backward }
    let(:data) do
      { 'payload' => { 'member' => { 'login' => 'member_name' } },
        'repo' => { 'name' => 'hamster/hello' },
        'actor' => { 'login' => 'hamster' },
        'created_at' => created_at }
    end

    it 'must fetch user and repo with appropriate data' do
      retriever.ght.expects(:ensure_repo).with('hamster', 'hello')
      retriever.ght.expects(:ensure_user).with('member_name', false, false)
      retriever.MemberEvent(data)
    end

    it 'must skip db insertion if project_member exists' do
      retriever.ght.expects(:ensure_repo).returns(id: 1)
      retriever.ght.expects(:ensure_user).returns(id: 1)
      Sequel::Mysql2::Dataset.any_instance.stubs(:first).returns(1)
      Sequel::Mysql2::Dataset.any_instance.expects(:insert).never
      retriever.MemberEvent(data)
    end

    it 'must insert data when created_at is passed' do
      retriever.ght.expects(:ensure_repo).returns(id: :project_id)
      retriever.ght.expects(:ensure_user).returns(id: :user_id)
      Sequel::Mysql2::Dataset.any_instance.stubs(:first)
      retriever.ght.expects(:date).returns(created_at)
      db_data = { user_id: :user_id, repo_id: :project_id, created_at: created_at }
      Sequel::Mysql2::Dataset.any_instance.expects(:insert).with(db_data)
      retriever.MemberEvent(data)
    end

    it 'must insert data when created_at is not passed' do
      user_created_at = Faker::Time.backward
      retriever.ght.expects(:ensure_user).returns(id: :user_id, created_at: user_created_at)
      retriever.ght.expects(:ensure_repo).returns(id: :project_id, created_at: user_created_at)
      Sequel::Mysql2::Dataset.any_instance.stubs(:first)
      retriever.ght.expects(:date).returns(user_created_at)
      retriever.stubs(:max).returns(user_created_at)
      db_data = { user_id: :user_id, repo_id: :project_id, created_at: user_created_at }
      Sequel::Mysql2::Dataset.any_instance.expects(:insert).with(db_data)
      retriever.MemberEvent(data.merge('created_at' => nil))
    end
  end

  describe 'CommitCommentEvent' do
    it 'must call ensure_commit_comment' do
      commit_sha = Faker::Internet.password
      comment_id = Faker::Number.number(3)
      data = { 'payload' => { 'comment' => { 'id' => comment_id, 'commit_id' => commit_sha } },
               'repo' => { 'name' => 'hamster/hello' } }
      retriever.ght.expects(:ensure_commit_comment).with('hamster', 'hello', commit_sha, comment_id)
      retriever.CommitCommentEvent(data)
    end
  end

  describe 'PullRequestEvent' do
    it 'must call ensure_pull_request' do
      repo_name = Faker::Name.first_name
      owner_login = Faker::Name.first_name
      pr_id = Faker::Number.number(2)
      created_at = Faker::Time.backward
      action = 'opened'
      data = { 'payload' => { 'pull_request' =>
                                { 'base' => { 'repo' =>
                                              { 'name' => repo_name,
                                                'owner' => { 'login' => owner_login } } } },
                              'action' => action,
                              'number' => pr_id },
               'actor' => { 'login' => 'hamster' },
               'created_at' => created_at,
               'repo' => { 'name' => 'hamster/hello' } }

      db_data = { 'owner' => owner_login, 'repo' => repo_name, 'number' => pr_id }
      retriever.persister.expects(:upsert).with(:pull_requests, db_data, data['payload']['pull_request'])
      retriever.ght.expects(:ensure_pull_request).with(owner_login, repo_name, pr_id, true,
                                                       true, true, action, 'hamster', created_at)
      retriever.PullRequestEvent(data)
    end
  end

  describe 'ForkEvent' do
    it 'must call ensure_fork' do
      fork_id = Faker::Number.number(3)
      data = { 'payload' => { 'forkee' => { 'id' => fork_id } },
               'repo' => { 'name' => 'hamster/hello' } }
      db_data = { 'owner' => 'hamster', 'repo' => 'hello', 'id' => fork_id }
      retriever.persister.expects(:upsert).with(:forks, db_data, data['payload']['forkee'])
      retriever.ght.expects(:ensure_fork).with('hamster', 'hello', fork_id)
      retriever.ForkEvent(data)
    end
  end

  describe 'PullRequestReviewCommentEvent' do
    it 'must call ensure_pullreq_comment' do
      comment_id = Faker::Number.number(3)
      pr_id = Faker::Number.number(2)
      data = { 'payload' => { 'comment' =>
                              { 'id' => comment_id,
                                '_links' => { 'pull_request' => { 'href' => "pulls/#{pr_id}" } } } },
               'repo' => { 'name' => 'hamster/hello' } }
      retriever.ght.expects(:ensure_pullreq_comment).with('hamster', 'hello', pr_id, comment_id)
      retriever.PullRequestReviewCommentEvent(data)
    end
  end

  describe 'IssuesEvent' do
    it 'must call ensure_issue' do
      issue_id = Faker::Number.number(3)
      data = { 'payload' => { 'issue' => { 'number' => issue_id } },
               'repo' => { 'name' => 'hamster/hello' } }
      retriever.ght.expects(:ensure_issue).with('hamster', 'hello', issue_id)
      retriever.IssuesEvent(data)
    end
  end

  describe 'IssueCommentEvent' do
    it 'must call ensure_issue_comment' do
      issue_id = Faker::Number.number(3)
      comment_id = Faker::Number.number(3)
      data = { 'payload' => { 'comment' => { 'id' => comment_id },
                              'issue' => { 'number' => issue_id } },
               'repo' => { 'name' => 'hamster/hello' } }
      retriever.ght.expects(:ensure_issue_comment).with('hamster', 'hello', issue_id, comment_id)
      retriever.IssueCommentEvent(data)
    end
  end

  describe 'CreateEvent' do
    it 'must call ensure_repo_recursive' do
      data = { 'payload' => { 'ref_type' => 'repository' },
               'repo' => { 'name' => 'hamster/hello' } }
      retriever.ght.expects(:ensure_repo).with('hamster', 'hello')
      retriever.ght.expects(:ensure_repo_recursive).with('hamster', 'hello')
      retriever.CreateEvent(data)
    end
  end
end
