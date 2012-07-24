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

  end

  down do

    drop_table :project_commits
  end
end