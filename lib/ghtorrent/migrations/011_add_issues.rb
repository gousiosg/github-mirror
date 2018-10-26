require 'sequel'

Sequel.migration do
  up do

    puts("Adding table issues")
    create_table :issues do
      primary_key :id
      foreign_key :repo_id, :projects
      foreign_key :reporter_id, :users, :null => true
      foreign_key :assignee_id, :users, :null => true
      Integer :issue_id, :null =>  false
      TrueClass :pull_request, :null => false
      foreign_key :pull_request_id, :pull_requests, :null => true
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
    end

    puts("Adding issue history")
    create_table :issue_events do
      Integer :event_id, :null => false
      foreign_key :issue_id, :issues, :null => false
      foreign_key :actor_id, :users, :null => false
      String :action, :null => false
      String :action_specific, :null => true, :size => 50
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
      primary_key [:event_id, :issue_id], :name=>:issue_events_pk
    end

    puts("Adding table issue comments")
    create_table :issue_comments do
      foreign_key :issue_id, :issues, :null => false
      foreign_key :user_id, :users, :null => false
      Integer :comment_id, :null =>  false
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
    end

    puts("Adding table repo labels")
    create_table :repo_labels do
      primary_key :id
      foreign_key :repo_id, :projects
      String :name, :size => 24, :null => false
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
    end

    puts("Adding table issue labels")
    create_table :issue_labels do
      foreign_key :label_id, :repo_labels
      foreign_key :repo_id, :projects
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
    end

    puts("Adding table repo milestones")
    create_table :repo_milestones do
      primary_key :id
      foreign_key :repo_id, :projects
      String :name, :size => 24, :null => false
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
    end
  end

  down do
    drop_table :repo_milestones
    drop_table :repo_labels
    drop_table :issue_comments
    drop_table :issue_events
    drop_table :issues
  end
end