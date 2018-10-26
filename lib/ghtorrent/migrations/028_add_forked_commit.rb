require 'sequel'

Sequel.migration do

  up do
    puts 'Adding column fork_commit to projects'

    alter_table(:projects) do
      add_foreign_key :forked_commit_id, :commits
    end

  end

  down do
    puts 'Dropping column fork_commit from projects'
    alter_table(:projects) do
      drop_foreign_key :forked_commit_id, :commits
    end
  end
end
