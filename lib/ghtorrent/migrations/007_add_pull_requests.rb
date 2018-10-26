require 'sequel'

Sequel.migration do
  up do

    puts("Adding table pull requests")

    create_table :pull_requests do
      primary_key :id
      foreign_key :head_repo_id, :projects
      foreign_key :base_repo_id, :projects, :null => false
      foreign_key :head_commit_id, :commits
      foreign_key :base_commit_id, :commits, :null => false
      foreign_key :user_id, :users, :null => false
      Integer :pullreq_id, :null => false
      TrueClass :intra_branch, :null => false
      unique([:pullreq_id, :base_repo_id])
    end

    puts("Adding table pull request history")

    create_table :pull_request_history do
      primary_key :id
      foreign_key :pull_request_id, :pull_requests, :null => false
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
      String :action, :null => false
      check(:action=>%w[opened closed merged synchronize reopened])
    end

    puts("Adding table pull request commits")

    create_table :pull_request_commits do
      foreign_key :pull_request_id, :pull_requests, :null => false
      foreign_key :commit_id, :commits, :null => false
      primary_key [:pull_request_id, :commit_id]
    end

    puts("Adding table pull request comments")

    create_table :pull_request_comments do
      foreign_key :pull_request_id, :pull_requests, :null => false
      foreign_key :user_id, :users, :null => false
      Integer :comment_id, :null =>  false
      Integer :position, :null => true
      String :body, :size => 256
      foreign_key :commit_id, :commits, :null => false
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
    end

  end

  down do

    drop_table :pull_requests
    drop_table :pull_request_history
    drop_table :pull_request_commits
    drop_table :pull_request_comments

  end
end