require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do
    puts("Creating table users")
    create_table :users do
      primary_key :id
      String :login, :unique => true, :null => false
      String :name
      String :company, :null => true
      String :location, :null => true
      String :email, :null => true
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
    end

    puts("Creating table projects")
    create_table :projects do
      primary_key :id
      String :url
      foreign_key :owner_id, :users
      String :name, :null => false
      String :description
      String :language
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
    end

    puts("Creating table commits")
    create_table :commits do
      primary_key :id
      String :sha, :size => 40, :unique => true
      foreign_key :author_id, :users
      foreign_key :committer_id, :users
      foreign_key :project_id, :projects
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
    end

    puts("Creating table commit_parents")
    create_table :commit_parents do
      foreign_key :commit_id, :commits, :null => false
      foreign_key :parent_id, :commits, :null => false
      primary_key [:commit_id, :parent_id]
    end

    puts("Creating table followers")
    create_table :followers do
      foreign_key :user_id, :users, :null => false
      foreign_key :follower_id, :users, :null => false
      DateTime :created_at, :null => false, :default=>Sequel::CURRENT_TIMESTAMP
      primary_key [:user_id, :follower_id]
    end
  end

  down do
    drop_table :users
    drop_table :projects
    drop_table :commits
    drop_table :commit_parents
    drop_table :followers
  end
end