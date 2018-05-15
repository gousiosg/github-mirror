require 'test_helper'

class GhtForkCommitTest < Minitest::Test
  describe 'ghtorrent transaction test' do
    before do
      session = 1
      @ght = GHTorrent::Mirror.new(session)
      @db = @ght.db
    end
    
    it 'should ensure fork commits using parent info' do
      user = create(:user, db_obj: @db)
      fork_repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: { 'login' => user.name_email }, forked_from: user.id, 
        db_obj: @db })
  
      repo = create(:repo, :github_project, { owner_id: user.id, 
        owner: {'login' => user.name_email}, 
        forked_from: fork_repo.id, 
        parent: {'name'  => fork_repo.name, 'owner' => {'login' =>user.name_email}, 
        db_obj: @db} } )
  
      commit = create(:commit, :github_commit, {project_id: repo.id, committer_id: user.id,  
        author: user,
        committer: user,
        commit:  { 'comment_count' => 0, 
                     'author' => user, 
                     'committer' => user},
        parents: [] })  
  
        @ght.stubs(:retrieve_repo).returns(repo)
        @ght.stubs(:retrieve_commits).returns ([commit])
          
        @ght.stubs(:retrieve_commit).returns(commit)
        
        puts "No common ancestor between #{repo.parent['owner']['login']}/#{repo.parent['name']} and #{user.name_email}/#{repo.name}"
        @ght.expects(:warn)
            .returns("No common ancestor between #{repo.parent['owner']['login']}/#{repo.parent['name']} and #{user.name_email}/#{repo.name}")
            .at_least_once
        @ght.expects(:warn)
            .with("Could not find fork commit for repo #{user.name_email}/#{repo.name}. Retrieving all commits.")
            .at_least_once
        sha = commit.sha
      
        retval = @ght.ensure_commits(user.name_email, repo.name, sha: sha, 
                          return_retrieved: true, num_commits: 3, fork_all: false)
        refute retval
    end
  end
end