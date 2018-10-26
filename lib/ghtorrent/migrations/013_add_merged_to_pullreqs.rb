require 'sequel'

Sequel.migration do
  up do

    puts "Adding column merged in table pull_requests"
    add_column :pull_requests, :merged, TrueClass, :null => false,
               :default => false

    puts "Updating pull_requests.merged"
    self.transaction(:rollback => :reraise, :isolation => :committed) do
      self << "update pull_requests
             set merged = '1'
             where exists (
              select *
              from pull_request_commits prc, project_commits pc
              where prc.commit_id = pc.commit_id
                  and prc.pull_request_id = pull_requests.id
                  and pc.project_id = pull_requests.base_repo_id
                  and pull_requests.base_repo_id <> pull_requests.head_repo_id);"

      self << "update pull_requests
      set merged = '1'
      where exists(
        select prh.created_at
        from pull_request_history prh
        where prh.action='merged' and prh.pull_request_id=pull_requests.id)"
    end

    puts 'Correcting intra_branch field'
    self.transaction(:rollback => :reraise, :isolation => :committed) do
      self << "update pull_requests set intra_branch = '1' where base_repo_id = head_repo_id"
    end
  end

  down do
    drop_column :pull_requests, :merged
  end
end
