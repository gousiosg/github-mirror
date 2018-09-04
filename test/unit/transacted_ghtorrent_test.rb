require 'test_helper'

describe 'TransactedGHTorrent' do
  let(:gh_torrent) { TransactedGHTorrent.new({}) }
  before { gh_torrent.stubs(:db).returns(stub('in_transaction?' => true)) }

  describe 'all methods' do
    it 'must call the equivalent method in super class' do
      {
        ensure_repo: 2,
        ensure_commit: 3,
        ensure_commit_comment: 4,
        ensure_fork: 3,
        ensure_fork_commits: 4,
        ensure_pull_request: 3,
        ensure_pullreq_comment: 4,
        ensure_issue: 3,
        ensure_issue_event: 4,
        ensure_issue_comment: 4,
        ensure_issue_label: 4,
        ensure_watcher: 3,
        ensure_repo_label: 3,
        ensure_user_followers: 1,
        ensure_orgs: 1,
        ensure_org: 1,
        ensure_topics: 2
      }.each do |method, no_of_args|
        args = Array.new(no_of_args) { Faker::Name.first_name }
        GHTorrent::Mirror.any_instance.expects(method)
        gh_torrent.send(method, *args)
      end
    end
  end

  describe 'db not in transaction' do
    it 'must call the super class transaction method' do
      gh_torrent.stubs(:db).returns(stub('in_transaction?' => false))
      GHTorrent::Mirror.any_instance.expects(:transaction)
      gh_torrent.ensure_repo(:foo, :bar)
    end
  end
end
