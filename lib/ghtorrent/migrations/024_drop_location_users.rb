require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do

  up do
    puts 'Dropping column location from users'
    alter_table :users do
      drop_column :location
    end
  end

  down do
    puts 'Adding column location to users'
    alter_table :users do
      add_column :location, String, :null => true
    end
  end
end
