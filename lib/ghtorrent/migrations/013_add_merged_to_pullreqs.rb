require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do

    puts "Adding column merged in table pull_requests"
    add_column :pull_requests, :merged, TrueClass, :null => false,
               :default => false

    puts "Updating pull_requests.merged"
    DB.transaction(:rollback => :reraise, :isolation => :committed) do
      DB << "update pull_requests pr
      set pr.merged = true
      where exists (select *
          from pull_request_commits prc, project_commits pc
          where prc.commit_id = pc.commit_id
          and prc.pull_request_id = pr.id
	        and pc.project_id = pr.base_repo_id
          and pr.base_repo_id <> pr.head_repo_id)"
      DB << "update pull_requests pr
      set pr.merged = true
      where exists(
        select prh.created_at
        from pull_request_history prh
        where prh.action='merged' and prh.pull_request_id=pr.id)"
    end

    puts "Correcting intra_branch field"
    DB.transaction(:rollback => :reraise, :isolation => :committed) do
      DB << "update pull_requests set intra_branch = true where base_repo_id = head_repo_id"
    end
  end

  down do
    drop_column :pull_requests, :merged
  end
end
