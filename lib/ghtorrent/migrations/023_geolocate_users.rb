require 'sequel'

Sequel.migration do

  up do
    puts 'Adding geo-location fields to table users'
    alter_table :users do
      add_column :long, BigDecimal, :size=>[11,8]
      add_column :lat, BigDecimal, :size=>[10,8]
      add_column :country_code, String, :fixed => :true, :size => 3
      add_column :state, String
      add_column :city, String
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
