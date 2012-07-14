require 'sequel'

Sequel.migration do
  up do

    puts("Adding table project members")

    create_table :project_members do
      foreign_key :repo_id, :commits, :null => false
      foreign_key :user_id, :users, :null => false
      DateTime :created_at, :null => false,
               :default => Sequel::CURRENT_TIMESTAMP
      primary_key [:repo_id, :user_id]
    end
  end

  down do

    drop_table :project_members

  end
end