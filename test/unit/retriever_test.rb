require 'test_helper'

class TestGHTorrentRetriever
  include GHTorrent::Retriever
  attr_accessor :ght, :db

  def persister
    @persister ||= ght.persister
  end

  def debug(_string); end
  alias warn debug
  alias info debug
end

class TestRetriever1
  include GHTorrent::Retriever
end

describe GHTorrent::Retriever do
  let(:retriever)       { TestGHTorrentRetriever.new }
  let(:other_retriever) { TestRetriever1.new }
  let(:repo_name)       { 'Test-Project' }
  let(:username)        { 'Priya5' }

  before do
    retriever.db = db
    retriever.ght = ght
  end

  it 'should raise error' do
    error =  -> { other_retriever.persister }.must_raise(Exception)
    error.message.must_match 'Unimplemented'
  end

  describe 'retrieve_user_byusername' do
    it 'should get the user from github' do
      VCR.use_cassette('github_get_user') do
        retriever.persister.expects(:store).once
        user = retriever.retrieve_user_byusername('User1')
        user.wont_be_nil
        user['id'].wont_be_nil
      end
    end

    it 'should return nil' do
      VCR.use_cassette('github_get_user') do
        retriever.persister.expects(:store).never
        retriever.retrieve_user_byusername('test_ght_user').must_be_nil
      end
    end

    it 'should return an existing user' do
      user = create(:user, type: 'User')
      retriever.persister.stubs(:find).returns([user])
      retriever.retrieve_user_byusername(user.login).must_equal user
    end
  end

  describe 'retrieve_user_byemail' do
    it 'should get the user from github' do
      VCR.use_cassette('github_get_user_by_email') do
        retriever.persister.expects(:store).once
        user = retriever.retrieve_user_byemail('User1@example.com', nil)
        user.wont_be_nil
        user['id'].wont_be_nil
      end
    end

    it 'should return nil if user not found by given email' do
      VCR.use_cassette('github_get_user_by_email') do
        retriever.retrieve_user_byemail('User2@example.com', nil).must_be_nil
      end
    end

    it 'should return nil if user not found by given name' do
      VCR.use_cassette('github_get_user_by_email') do
        retriever.retrieve_user_byemail('User2@example.com', 'User1 User2').must_be_nil
      end
    end

    it 'should return nil if user not found by given name and email' do
      user = create(:user, type: 'User')
      retriever.stubs(:retrieve_user_byusername).with('User2_ght').returns(user)

      VCR.use_cassette('github_get_user_by_email') do
        retriever.retrieve_user_byemail('User2@example.com', 'User2 GHT').must_be_nil
      end
    end

    it 'should return user' do
      user = create(:user, type: 'User')
      retriever.stubs(:retrieve_user_byusername).with('User2_ght').returns(user)

      VCR.use_cassette('github_get_user_by_email') do
        retriever.retrieve_user_byemail('User2_ght@example.com', 'User2 GHT').wont_be_nil
      end
    end

    it 'should not return user' do
      retriever.stubs(:retrieve_user_byusername).with('User2_ght').returns(nil)
      VCR.use_cassette('github_get_user_by_email') do
        retriever.retrieve_user_byemail('User2_ght@example.com', 'User2 GHT').must_be_nil
      end
    end

    it 'should get the user from github' do
      VCR.use_cassette('github_get_user_by_email') do
        user = retriever.retrieve_user_byemail('User1_ght@example.com', nil)
        user.wont_be_nil
        user['id'].wont_be_nil
      end
    end
  end

  describe 'retrieve_user_follower' do
    it 'should get the follower' do
      follower = create(:follower)
      retriever.persister.stubs(:find).returns([follower])
      retriever.retrieve_user_follower('followed_user', 'follower').must_equal follower
    end

    it 'should return nil' do
      VCR.use_cassette('github_get_followers') do
        retriever.persister.stubs(:find).returns([])
        retriever.retrieve_user_follower('notalex', 'follower').must_be_nil
      end
    end

    it 'should return followed user' do
      VCR.use_cassette('github_get_followers') do
        retriever.persister.stubs(:find).with(:followers, 'follows' => username, 'login' => 'follower').once.returns([])
        retriever.persister.stubs(:find).with(:followers, 'follows' => username, 'login' => 'asahu8').once.returns(['follower'])
        retriever.persister.stubs(:find).with(:followers, 'follows' => username).returns(['follower'])
        retriever.retrieve_user_follower(username, 'follower').must_be_nil
      end
    end
  end

  describe 'retrieve_user_following' do
    it "should get the user's following" do
      VCR.use_cassette('github_get_user_following') do
        follower = create(:follower)
        retriever.persister.stubs(:find).returns([follower])
        retriever.retrieve_user_following(username).must_equal [follower]
      end
    end

    it "should get the user's following" do
      VCR.use_cassette('github_get_user_following') do
        follower = create(:follower, login: username)
        retriever.persister.stubs(:find).with(:followers, 'follows' => 'ProsenjitSaha', 'login' => username).returns([])
        retriever.persister.stubs(:find).with(:followers, 'follows' => 'ProsenjitSaha').returns([follower])
        follower.stubs(:delete).returns(true)
        retriever.persister.stubs(:find).with(:followers, 'login' => username).returns([follower])
        retriever.retrieve_user_following(username).must_equal [follower]
      end
    end
  end

  describe 'retrieve_pull_request_commit' do
    it 'should return a pull request commit' do
      db.transaction(rollback: :always) do
        user = create(:user, db_obj: db)
        repo = create(:repo, :github_project, owner_id: user.id,
                                              owner: { 'login' => user.name_email },
                                              db_obj: db)

        commit = create(:sha, :github_commit,  project_id: repo.id, committer_id: user.id,
                                               author: user,
                                               committer: user,
                                               commit:  { comment_count: 0, author: user,
                                                          committer: user },
                                               parents: [], db_obj: db)
        pull_request = create(:pull_request, :github_pr, base_repo_id: repo.id,
                                                         base_commit_id: commit.id, db_obj: db)

        pr_commit = create(:pull_request_commit, :github_pr_commit,
                           pull_request_id: pull_request.id, commit_id: commit.id, repo_name: repo.name,
                           owner: user.name_email, sha: commit.sha, db_obj: db)
        retriever.persister.stubs(:find).with(:pull_request_commits, 'sha' => pr_commit.sha).returns([pr_commit])
        retriever.retrieve_pull_request_commit(pull_request, repo, pr_commit.sha, user).must_equal pr_commit
      end
    end

    it 'should return nil' do
      retriever.stubs(:retrieve_commit).returns(nil)
      retriever.retrieve_pull_request_commit('pr_commit', 'repo', 'sha', 'user').must_be_nil
    end

    it 'should fetch the commit from github' do
      pull_request = create(:pull_request, :github_pr)
      sha = 'e1f1ada440fb107366d68599107aa365c1e14255'

      VCR.use_cassette('github_get_user_commits') do
        commit = retriever.retrieve_pull_request_commit(pull_request, repo_name, sha, username)
        commit.wont_be_nil
        commit['sha'].must_equal sha
      end
    end
  end

  describe 'retrieve_commit' do
    sha = 'df9e4928f5259ad181b6e7104be9868f'

    it 'should return nil' do
      VCR.use_cassette('github_get_user_commits') do
        retriever.retrieve_commit(repo_name, sha, username).must_be_nil
      end
    end

    it 'should return commit from database' do
      commit = create(:commit)
      retriever.persister.stubs(:find).with(:commits, 'sha' => commit.sha).returns([commit])
      retriever.retrieve_commit(repo_name, commit.sha, username).must_equal commit
    end

    it 'should delete the patch from commit files' do
      GHTorrent::Settings::DEFAULTS[:commit_handling] = 'trim'
      VCR.use_cassette('github_get_user_commits') do
        commit = retriever.retrieve_commit(repo_name, 'e1f1ada440fb107366d68599107aa365c1e14255', username)
        commit['files'].first.keys.wont_include('patch')
      end
    end
  end

  describe 'retrieve_commits' do
    it 'should return all the commits of the user' do
      VCR.use_cassette('github_get_user_commits') do
        retriever.retrieve_commits(repo_name, nil, username, 1).wont_be_nil
      end
    end

    it 'should return all the commits of the user' do
      sha = 'e1f1ada440fb107366d68599107aa365c1e14255'
      VCR.use_cassette('github_get_user_commits') do
        commit = retriever.retrieve_commits(repo_name, sha, username, 1)
        commit.first['sha'].must_equal sha
      end
    end
  end

  describe 'retrieve_repo' do
    it 'should return the repo from github' do
      VCR.use_cassette('github_get_user_repo') do
        repo = retriever.retrieve_repo(username, repo_name)
        repo['name'].must_equal repo_name
        repo['id'].wont_be_nil
      end
    end

    it 'should return the repo from database' do
      repo = create(:project)
      retriever.persister.stubs(:find).returns([repo])
      repo = retriever.retrieve_repo(username, repo_name).must_equal repo
    end

    it 'should update the repo' do
      repo = create(:project, name: repo_name)
      VCR.use_cassette('github_get_user_repo') do
        retriever.persister.stubs(:find).returns([repo])
        retriever.retrieve_repo(username, repo_name, true)
        repo.name.must_equal repo_name
      end
    end

    it 'should return nil' do
      VCR.use_cassette('github_get_user_repo') do
        retriever.retrieve_repo(username, 'Test-project1').must_be_nil
      end
    end
  end

  describe 'retrieve_languages' do
    it 'should return repository languages' do
      VCR.use_cassette('github_get_repo_languages') do
        retriever.retrieve_languages(username, repo_name).keys.must_include 'Ruby'
      end
    end
  end

  describe 'retrieve_orgs' do
    it 'should return empty if user does not have organizations' do
      VCR.use_cassette('github_get_user_organizations') do
        retriever.retrieve_orgs(username).must_be_empty
      end
    end

    it 'should return user organizations' do
      VCR.use_cassette('github_get_user_organizations') do
        retriever.retrieve_orgs('Priya').wont_be_empty
      end
    end
  end

  describe 'retrieve_org' do
    it 'should get the user from github' do
      VCR.use_cassette('github_get_user') do
        user = retriever.retrieve_org('User1')
        user.wont_be_nil
        user['id'].wont_be_nil
      end
    end
  end

  describe 'retrieve_org_members' do
    let(:org) { 'ghtorrent' }

    it 'should fetch and store the organisation members' do
      VCR.use_cassette('github_get_org_members') do
        ght_user = create(:user, login: 'ght_user')
        org_member = create(:organization_member, login: ght_user.login)
        retriever.stubs(:retrieve_org).returns(ght_user)
        retriever.persister.stubs(:find).with(:org_members, 'org' => org).returns([], [org_member])
        retriever.retrieve_org_members(org).must_equal [ght_user]
      end
    end

    it 'should return the matchinng member from database' do
      VCR.use_cassette('github_get_org_members') do
        ght_user = create(:user, login: 'ght_user')
        org_member = create(:organization_member, login: ght_user.login, org: org)
        retriever.stubs(:retrieve_org).returns(ght_user)
        retriever.persister.stubs(:find).with(:org_members, 'org' => org).returns([org_member])
        retriever.retrieve_org_members(org).must_equal [ght_user]
      end
    end
  end

  describe 'retrieve_commit_comments' do
    it 'should return the commit comments' do
      commit_comment = create(:commit_comment, id: 29_177_690)
      sha = '3ea09dbd4d643220ddac94d9ada3c001a820a4dc'

      VCR.use_cassette('github_get_commit_comments') do
        retriever.persister.stubs(:find).with(:commit_comments, 'commit_id' => sha, 'id' => commit_comment.id).returns([])
        retriever.persister.stubs(:find).with(:commit_comments, 'commit_id' => sha).returns([commit_comment])
        retriever.retrieve_commit_comments(username, repo_name, sha).must_equal [commit_comment]
      end
    end

    it 'should return empty if comments do not exists' do
      commit_comment = create(:commit_comment)
      sha = '6076dd729adf62fe36c4d62d2ea5ec1e2e4f7b9f'

      VCR.use_cassette('github_get_commit_comments') do
        retriever.persister.stubs(:find).with(:commit_comments, 'commit_id' => '6076dd729adf62fe36c4d62d2ea5ec1e2e4f7b9f').returns([])
        retriever.retrieve_commit_comments(username, repo_name, sha).must_be_empty
      end
    end
  end

  describe 'retrieve_commit_comment' do
    it 'should return the single comment of the commit from github and store in the database' do
      commit_comment = create(:commit_comment, id: 29_177_690)
      sha = '3ea09dbd4d643220ddac94d9ada3c001a820a4dc'

      VCR.use_cassette('github_get_commit_comments') do
        retriever.persister.stubs(:find).with(:commit_comments, 'commit_id' => sha, 'id' => commit_comment.id).returns([], [commit_comment])
        retriever.retrieve_commit_comment(username, repo_name, sha, commit_comment.id).must_equal commit_comment
      end
    end

    it 'should return the comment from the database' do
      commit_comment = create(:commit_comment, id: 29_177_690)
      sha = '3ea09dbd4d643220ddac94d9ada3c001a820a4dc'

      retriever.persister.stubs(:find).with(:commit_comments, 'commit_id' => sha, 'id' => commit_comment.id).returns([commit_comment])
      retriever.retrieve_commit_comment(username, repo_name, sha, commit_comment.id).must_equal commit_comment
    end

    it 'should return nil for an invalid comment_id' do
      commit_comment = create(:commit_comment, id: 1)
      sha = '6076dd729adf62fe36c4d62d2ea5ec1e2e4f7b9f'

      VCR.use_cassette('github_get_commit_comments') do
        retriever.retrieve_commit_comment(username, repo_name, sha, commit_comment.id).must_be_nil
      end
    end
  end

  describe 'retrieve_watchers' do
    it 'should get the watchers of the repo' do
      VCR.use_cassette('github_get_repo_watchers') do
        retriever.retrieve_watchers(username, repo_name).must_be_empty
      end
    end
  end

  describe 'retrieve_watcher' do
    it 'should return a watcher' do
      watcher = create(:watcher)
      retriever.persister.stubs(:find).with(:watchers, 'repo' => repo_name, 'owner' => username, 'login' => username).returns([watcher])
      retriever.retrieve_watcher(username, repo_name, username).must_equal watcher
    end
  end

  describe 'retrieve_pull_requests' do
    it 'should fetch pull_requests details from github and refresh the data' do
      pull_request = create(:pull_request)
      retriever.persister.stubs(:find).with(:pull_requests, 'repo' => repo_name, 'owner' => username, 'number' => 1).returns([pull_request])
      retriever.persister.stubs(:find).with(:pull_requests, 'repo' => repo_name, 'owner' => username).returns([pull_request])
      VCR.use_cassette('github_get_repo_prs') do
        retriever.retrieve_pull_requests(username, repo_name, true).must_equal [pull_request]
      end
    end

    it 'should fetch pull_requests details from github' do
      pull_request = create(:pull_request)
      retriever.persister.stubs(:find).with(:pull_requests, 'repo' => repo_name, 'owner' => username, 'number' => 1).returns([pull_request])
      retriever.persister.stubs(:find).with(:pull_requests, 'repo' => repo_name, 'owner' => username).returns([pull_request])
      VCR.use_cassette('github_get_repo_prs') do
        retriever.retrieve_pull_requests(username, repo_name, false).must_equal [pull_request]
      end
    end
  end

  describe 'retrieve_pull_request' do
    it 'should return nil' do
      VCR.use_cassette('github_get_repo_prs') do
        retriever.retrieve_pull_request(username, repo_name, '10').must_be_nil
      end
    end

    it 'should fetch pull_requests details from github and refresh the data' do
      db.transaction(rollback: :always) do
        user = create(:user, db_obj: db)
        repo = create(:repo, :github_project, owner_id: user.id,
                                              owner: { 'login' => user.name_email },
                                              db_obj: db)

        commit = create(:sha, :github_commit,  project_id: repo.id, committer_id: user.id,
                                               author: user,
                                               committer: user,
                                               commit:  { comment_count: 0, author: user,
                                                          committer: user },
                                               parents: [], db_obj: db)
        pull_request = create(:pull_request, :github_pr, base_repo_id: repo.id,
                                                         base_commit_id: commit.id, db_obj: db)
        VCR.use_cassette('github_get_repo_prs') do
          retriever.persister.stubs(:find).with(:pull_requests, 'repo' => repo_name,
                                                                'owner' => username, 'number' => pull_request.id).returns([pull_request])
          retriever.retrieve_pull_request(username, repo_name, pull_request.id).must_equal pull_request
        end
      end
    end
  end

  describe 'retrieve_forks' do
    it 'should fetch the repository forks' do
      repo = create(:repo, :github_project, id: 135_258_762)

      VCR.use_cassette('github_get_repo_forks') do
        retriever.persister.stubs(:find).with(:forks, 'repo' => repo_name, 'owner' => username, 'id' => repo.id).returns([repo])
        retriever.persister.stubs(:find).with(:forks, 'repo' => repo_name, 'owner' => username).returns([repo])
        retriever.retrieve_forks(username, repo_name).must_equal [repo]
      end
    end
  end

  describe 'retrieve_fork' do
    it 'should fetch the repository forks' do
      repo = create(:repo, :github_project, id: 135_258_762)

      VCR.use_cassette('github_get_repo_forks') do
        retriever.persister.stubs(:find).with(:forks, 'repo' => repo_name, 'owner' => username, 'id' => repo.id).returns([repo])
        retriever.persister.stubs(:find).with(:forks, 'repo' => repo_name, 'owner' => username).returns([repo])
        retriever.retrieve_fork(username, repo_name, repo.id).must_equal repo
      end
    end
  end

  describe 'retrieve_pull_req_commits' do
    it 'should fetch the pull request commits' do
      pull_request = create(:pull_request, id: 1)
      commit = create(:commit, sha: '6076dd729adf62fe36c4d62d2ea5ec1e2e4f7b9f')
      retriever.persister.stubs(:find).with(:commits, 'sha' => commit.sha).returns([commit])

      VCR.use_cassette('github_get_repo_prs') do
        retriever.retrieve_pull_req_commits(username, repo_name, pull_request.id).must_equal [commit]
      end
    end
  end

  describe 'retrieve_pull_req_comments' do
    it 'should get the pull requests comments' do
      pull_request = create(:pull_request, id: 1)
      pull_request_comment = create(:pull_request_comment, pull_request_id: pull_request.id, id: 191_363_245)

      VCR.use_cassette('github_get_repo_prs') do
        retriever.persister.stubs(:find).with(:pull_request_comments, 'owner' => username, 'repo' => repo_name,
                                                                      'pullreq_id' => pull_request.id, 'id' => pull_request_comment.id).returns([])
        retriever.persister.stubs(:find).with(:pull_request_comments, 'owner' => username, 'repo' => repo_name,
                                                                      'pullreq_id' => pull_request.id).returns([pull_request_comment])
        retriever.retrieve_pull_req_comments(username, repo_name, pull_request.id).must_equal [pull_request_comment]
      end
    end
  end

  describe 'retrieve_pull_req_comment' do
    let(:pull_request) { create(:pull_request, id: 1) }
    let(:pull_request_comment) { create(:pull_request_comment, pull_request_id: pull_request.id, id: 191_363_245) }

    it 'should get first comment of the pull requests from github' do
      VCR.use_cassette('github_get_repo_prs') do
        retriever.persister.stubs(:find).with(:pull_request_comments, 'owner' => username,
                                                                      'repo' => repo_name, 'pullreq_id' => pull_request.id,
                                                                      'id' => pull_request_comment.id).returns([], [pull_request_comment])
        retriever.retrieve_pull_req_comment(username, repo_name, pull_request.id, pull_request_comment.id).must_equal pull_request_comment
      end
    end

    it 'should return nil' do
      comment_id = 1

      VCR.use_cassette('github_get_repo_prs') do
        retriever.persister.stubs(:find).with(:pull_request_comments, 'owner' => username, 'repo' => repo_name,
                                                                      'pullreq_id' => pull_request.id, 'id' => comment_id).returns([])
        retriever.retrieve_pull_req_comment(username, repo_name, pull_request.id, comment_id).must_be_nil
      end
    end

    it 'should return comment from database' do
      retriever.persister.stubs(:find).with(:pull_request_comments, 'owner' => username, 'repo' => repo_name,
                                                                    'pullreq_id' => pull_request.id, 'id' => pull_request_comment.id).returns([pull_request_comment])
      retriever.retrieve_pull_req_comment(username, repo_name, pull_request.id, pull_request_comment.id).must_equal pull_request_comment
    end
  end

  describe 'retrieve_issues' do
    it 'should fetch the repository issues' do
      issue = create(:issue, id: 326_958_432)

      VCR.use_cassette('github_get_repo_issues') do
        retriever.persister.stubs(:find).with(:issues, 'repo' => repo_name, 'owner' => username, 'number' => 2).returns([])
        retriever.persister.stubs(:find).with(:issues, 'repo' => repo_name, 'owner' => username, 'number' => 1).returns([issue])
        retriever.persister.stubs(:find).with(:issues, 'repo' => repo_name, 'owner' => username).returns([issue])
        retriever.retrieve_issues(username, repo_name).must_equal [issue]
      end
    end
  end

  describe 'retrieve_issue' do
    it 'should fetch a single repository issue' do
      issue = create(:issue, id: 326_958_432)

      VCR.use_cassette('github_get_repo_issues') do
        retriever.persister.stubs(:find).with(:issues, 'repo' => repo_name, 'owner' => username, 'number' => issue.id).returns([issue])
        retriever.retrieve_issue(username, repo_name, issue.id).must_equal issue
      end
    end
  end

  describe 'retrieve_issue_events' do
    it 'should fetch events of the repository issue' do
      issue = create(:issue, id: 2)
      event = create(:issue_event, id: 1_653_232_576)

      VCR.use_cassette('github_get_repo_issue_events') do
        retriever.persister.stubs(:find).with(:issue_events, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id, 'id' => event.id).returns([])
        retriever.persister.stubs(:find).with(:issue_events, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id).returns([event])
        retriever.retrieve_issue_events(username, repo_name, issue.id).must_equal [event]
      end
    end
  end

  describe 'retrieve_issue_event' do
    it 'should fetch a single event of the repository issue from github and store in database' do
      issue = create(:issue, id: 2)
      event = create(:issue_event, id: 1_653_232_576)

      VCR.use_cassette('github_get_repo_issue_events') do
        retriever.persister.stubs(:find).with(:issue_events, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id, 'id' => event.id).returns([], [event])
        retriever.retrieve_issue_event(username, repo_name, issue.id, event.id).must_equal event
      end
    end

    it 'should return a single event from database' do
      issue = create(:issue, id: 2)
      event = create(:issue_event, id: 1_653_232_576)

      retriever.persister.stubs(:find).with(:issue_events, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id, 'id' => event.id).returns([event])
      retriever.retrieve_issue_event(username, repo_name, issue.id, event.id).must_equal event
    end

    it 'should return nil for an invalid event_id' do
      issue = create(:issue, id: 2)
      event = create(:issue_event, id: 165)

      VCR.use_cassette('github_get_repo_issue_events') do
        retriever.persister.stubs(:find).with(:issue_events, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id, 'id' => event.id).returns([])
        retriever.retrieve_issue_event(username, repo_name, issue.id, event.id).must_be_nil
      end
    end
  end

  describe 'retrieve_issue_comments' do
    it 'should fetch comments of the repository issue' do
      issue = create(:issue, id: 2)
      comment = create(:issue_comment, id: 393_117_252)

      VCR.use_cassette('github_get_repo_issue_comments') do
        retriever.persister.stubs(:find).with(:issue_comments, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id, 'id' => comment.id).returns([])
        retriever.persister.stubs(:find).with(:issue_comments, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id).returns([comment])
        retriever.retrieve_issue_comments(username, repo_name, issue.id).must_equal [comment]
      end
    end
  end

  describe 'retrieve_issue_comment' do
    let(:issue) { create(:issue, id: 2) }
    let(:comment) { create(:issue_comment, id: 393_117_252) }

    it 'should fetch a single comment of the repository issue from github and store in database' do
      VCR.use_cassette('github_get_repo_issue_comments') do
        retriever.persister.stubs(:find).with(:issue_comments, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id, 'id' => comment.id).returns([], [comment])
        retriever.retrieve_issue_comment(username, repo_name, issue.id, comment.id).must_equal comment
      end
    end

    it 'should return a single comment from database' do
      retriever.persister.stubs(:find).with(:issue_comments, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id, 'id' => comment.id).returns([comment])
      retriever.retrieve_issue_comment(username, repo_name, issue.id, comment.id).must_equal comment
    end

    it 'should return nil for an invalid comment_id' do
      comment = create(:issue_comment, id: 165)

      VCR.use_cassette('github_get_repo_issue_comments') do
        retriever.persister.stubs(:find).with(:issue_comments, 'owner' => username, 'repo' => repo_name, 'issue_id' => issue.id, 'id' => comment.id).returns([])
        retriever.retrieve_issue_comment(username, repo_name, issue.id, comment.id).must_be_nil
      end
    end
  end

  describe 'retrieve_repo_labels' do
    let(:repo_label) { create(:repo_label) }

    it 'should fetch the repository labels' do
      VCR.use_cassette('github_get_repo_labels') do
        retriever.persister.stubs(:find).returns([repo_label])
        retriever.retrieve_repo_labels(username, repo_name).must_equal [repo_label]
      end
    end
  end

  describe 'retrieve_repo_label' do
    let(:repo_label) { create(:repo_label) }

    it 'should fetch the repository issues' do
      VCR.use_cassette('github_get_repo_labels') do
        retriever.persister.stubs(:find).returns([repo_label])
        retriever.retrieve_repo_label(username, repo_name, 'bug').must_equal repo_label
      end
    end
  end

  describe 'retrieve_issue_labels' do
    let(:issue) { create(:issue, id: 2) }

    it 'should return repository issue labels' do
      VCR.use_cassette('github_get_issue_labels') do
        retriever.retrieve_issue_labels(username, repo_name, issue.id).wont_be_empty
      end
    end
  end

  describe 'retrieve_topics' do
    let(:topic_name) { 'beginner-project' }
    let(:repo_topic) { create(:project_topic, topic: topic_name) }

    it 'should fetch the repository topics and store in the database' do
      VCR.use_cassette('github_get_repo_topics') do
        retriever.persister.expects(:store).once
        retriever.retrieve_topics(username, repo_name).must_equal [topic_name]
      end
    end

    it 'should return empty if project does not having topics' do
      VCR.use_cassette('github_get_repo_topics') do
        retriever.retrieve_topics('Priya101', repo_name).must_be_empty
      end
    end

    it 'should fetch the repository topics from github and does not store in database' do
      VCR.use_cassette('github_get_repo_topics') do
        retriever.persister.expects(:find).with(:topics, 'owner' => username, 'repo' => repo_name).returns([repo_topic])
        retriever.persister.expects(:store).never
        retriever.retrieve_topics(username, repo_name).must_equal [topic_name]
      end
    end
  end

  describe 'get_events' do
    it 'should return the Github events' do
      VCR.use_cassette('github_get_events') do
        retriever.get_events.wont_be_empty
      end
    end
  end

  describe 'get_repo_events' do
    it 'should fetch the repo event and store in the database' do
      VCR.use_cassette('github_get_events') do
        event = OpenStruct.new(id: '7737749979')
        retriever.persister.stubs(:find).with(:events, 'id' => event.id).returns([])
        retriever.persister.stubs(:find).with(:events, 'repo.name' => "#{username}/#{repo_name}").returns([event])
        retriever.get_repo_events(username, repo_name).must_equal [event]
      end
    end

    it 'should fetch the repo event and return the matching event from database' do
      VCR.use_cassette('github_get_events') do
        event = OpenStruct.new(id: '7737749979')
        retriever.persister.stubs(:find).with(:events, 'id' => event.id).returns([event])
        retriever.persister.stubs(:find).with(:events, 'repo.name' => "#{username}/#{repo_name}").returns([event])
        retriever.get_repo_events(username, repo_name).must_equal [event]
      end
    end
  end

  describe 'get_event' do
    it 'should return a matching event' do
      event = OpenStruct.new(id: 1)
      retriever.persister.stubs(:find).with(:events, 'id' => event.id).returns(event)
      retriever.get_event(event.id).must_equal event
    end
  end

  describe 'retrieve_master_branch_diff' do
    it 'should fetch the diff of two branch' do
      VCR.use_cassette('github_get_branch_diff') do
        diff = retriever.retrieve_master_branch_diff(username, repo_name, 'test', username, repo_name, 'master')
        diff['files'].wont_be_empty
        diff['files'][0]['changes'].must_equal 1
      end
    end
  end

  describe 'restricted_page_request' do
    it 'should make an api request' do
      VCR.use_cassette('github_get_repo') do
        url = 'https://api.github.com/repos/blackducksoftware/ohcount'
        retriever.send(:restricted_page_request, url, -1).wont_be_empty
      end
    end
  end

  describe 'ghurl' do
    it 'should return a github url' do
      path = Faker::Lorem.word
      retriever.send(:ghurl, path, 1).must_equal "https://api.github.com/#{path}?page=1&per_page=100"
    end

    it 'should return a github url with query string' do
      path = "#{Faker::Lorem.word}?name=#{Faker::Name.first_name}"
      retriever.send(:ghurl, path, 1).must_equal "https://api.github.com/#{path}&page=1&per_page=100"
    end
  end
end
