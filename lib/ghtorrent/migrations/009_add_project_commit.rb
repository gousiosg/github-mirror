require 'sequel'

Sequel.migration do
  up do

    puts("Create table project_commits")
    create_table :project_commits do
      foreign_key :project_id, :projects
      foreign_key :commit_id, :commits
      primary_key [:project_id, :commit_id]
    end

    puts("Migrating data from commits to project_commits")
    transaction(:rollback => :reraise, :isolation => :committed) do
      self[:project_commits].insert([:project_id, :commit_id],
                                    self[:commits].select(:project_id, :id))
    end

    #puts("Droping column project_id from commits")
    #alter_table :commits do
    #  drop_column :project_id
    #end

  end

  down do

    #puts("Adding column project_it to commits")
    #alter_table :commits do
    #  add_foreign_key :project_id, :projects
    #end

    puts("Migrating data from project_commits to commits")
    transaction(:rollback => :reraise, :isolation => :committed) do
      self[:project_commits].all do |r|
        self[:commits].filter(:id => r[:commit_id]).update(:project_id => r[:project_id])
      end
    end

    drop_table :project_commits
  end
end