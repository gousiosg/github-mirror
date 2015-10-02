require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do

  up do
    puts 'Adding geo-location fields to table users'
    alter_table :users do
      add_column :long, BigDecimal, :size=>[11,8], :default => :null
      add_column :lat, BigDecimal, :size=>[10,8], :default => :null
      add_column :country_code, String, :fixed => :true, :size => 3, :default => :null
      add_column :state, :location, :default => :null
      add_column :city, :location, :default => :null
    end
  end

  down do
    puts 'Dropping geo-location fields from table users'
    alter_table :users do
      drop_column :long
      drop_column :lat
      drop_column :country_code
      drop_column :state
      drop_column :city
    end
  end
end
