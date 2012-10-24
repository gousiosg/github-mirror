require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do

    puts("Adding table issues")
    create_table :issues do
      primary_key :id
      foreign_key :repo_id, :projects
      foreign_key :assignee_id, :users
      TrueClass :pull_request, :null => false
      foreign_key :pull_request_id, :pull_requests, :null => true
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
    end

    puts("Adding issue history")
    create_table :issue_history do
      primary_key :id
      foreign_key :issue_id, :issues, :null => false
      foreign_key :actor_id, :users, :null => false
      String :action, :null => false
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
      check(:action=>%w[closed reopened subscribed merged referenced mentioned assigned])
    end

    puts("Adding table issue comments")
    create_table :issue_comments do
      primary_key :id
    end
  end

  down do
    drop_table :issues
    drop_table :issue_history
    drop_table :issue_comments
  end
end