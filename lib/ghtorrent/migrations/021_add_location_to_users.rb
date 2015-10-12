require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do

  up do
    puts 'Add Geo Columns to Users'
      add_column :geo_latlng, :location, :default => null
      add_column :geo_country, :location, :default => null
      add_column :geo_state, :location, :default => null
      add_column :geo_city, :location, :default => null
  end

  down do
    puts 'Remove Geo Columns from Users'
    alter_table :users do
      drop_column :geo_latlng
      drop_column :geo_country
      drop_column :geo_state
      drop_column :geo_city
    end
  end
end
