require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do
    puts 'Dropping columns merged and user_id from pull_requests'
    drop_column :pull_requests, :merged
    drop_column :pull_requests, :user_id
  end

  down do
    puts 'Adding columns merged and user_id to pull_requests'
    add_column :pull_requests, :merged, TrueClass, :null => false,
               :default => false

    add_foreign_key :user_id, :users, :null => false

  end
end
