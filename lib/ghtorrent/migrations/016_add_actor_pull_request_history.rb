require 'sequel'

Sequel.migration do
  up do
    puts "Adding column user_id to table pull_rq"

    alter_table :pull_request_history do
      add_foreign_key :actor_id, :users
    end

    puts 'Remember to run the fixes/update_pullreq_entries_from_events.rb
 script to mark deleted projects'
  end

  down do
    alter_table :pull_request_history do
      drop_column :actor_id
    end
  end
end
