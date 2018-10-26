require 'sequel'

Sequel.migration do

  up do
    puts 'Dropping columns merged and user_id from pull_requests'
    alter_table :pull_requests do
      drop_column :merged
      drop_foreign_key :user_id
    end
  end

  down do
    puts 'Adding columns merged and user_id to pull_requests'
    add_column :pull_requests, :merged, TrueClass, :null => false,
      :default => false

    add_foreign_key :user_id, :users, :null => false

  end
end
