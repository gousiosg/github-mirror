require 'sequel'

Sequel.migration do

  up do
    puts 'Add column deleted to users'
      add_column :users, :deleted, TrueClass, :null => false, :default => false
  end

  down do
    puts 'Drop column deleted from users'
    alter_table :users do
      drop_column :deleted
    end
  end
end
