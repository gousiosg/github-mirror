require 'sequel'

Sequel.migration do

  up do
    puts 'Adding column etag to table projects'
    add_column :projects, :etag, String,
               :null => true, :size => 40
  end

  down do
    puts 'Deleting column updated_at from table projects'
    alter_table :projects do
      drop_column :etag
    end
  end
end
