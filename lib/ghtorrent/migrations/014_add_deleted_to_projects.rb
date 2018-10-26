require 'sequel'

Sequel.migration do
  up do

    puts 'Adding column deleted in table projects'
    add_column :projects, :deleted, TrueClass, :null => false,
               :default => false

    puts 'Field deleted added'
    puts 'Remember to run the fixes/update_deleted.rb script to mark deleted projects'
  end

  down do
    alter_table :projects do
      drop_column :deleted
    end
  end
end