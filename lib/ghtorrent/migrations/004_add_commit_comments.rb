require 'sequel'

Sequel.migration do
  up do

    puts("Adding table commit comments")

    create_table :commit_comments do
      primary_key :id
      foreign_key :commit_id, :commits, :null => false
      foreign_key :user_id, :users, :null => false
      String :body, :size => 256
      Integer :line, :null => true
      Integer :position, :null => true
      Integer :comment_id, :null => false, :unique => true
      String :ext_ref_id, :null => false, :size => 24, :default => "0"
      DateTime :created_at, :null => false,
               :default => Sequel::CURRENT_TIMESTAMP
    end
  end

  down do

    drop_table :commit_comments

  end
end
