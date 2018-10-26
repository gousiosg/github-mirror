require 'sequel'

Sequel.migration do

  up do
    puts 'Dropping column ext_ref_id from all tables'

    drop_column :users, :ext_ref_id
    drop_column :projects, :ext_ref_id
    drop_column :commits, :ext_ref_id
    drop_column :followers, :ext_ref_id
    drop_column :commit_comments, :ext_ref_id
    drop_column :pull_request_history, :ext_ref_id
    drop_column :pull_request_comments, :ext_ref_id
    drop_column :issues, :ext_ref_id
    drop_column :issue_events, :ext_ref_id
    drop_column :issue_comments, :ext_ref_id
    drop_column :repo_labels, :ext_ref_id
    drop_column :repo_milestones, :ext_ref_id
    drop_column :watchers, :ext_ref_id
  end

  down do
    puts 'Add column ext_ref_id to all tables'
    add_column :users, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :projects, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :commits, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :followers, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :commit_comments, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :pull_request_history, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :pull_request_comments, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :issues, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :issue_events, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :issue_comments, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :repo_labels, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :repo_milestones, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    add_column :watchers, :ext_ref_id, String, :null => false, :size => 24, :default => "0"
  end
end
