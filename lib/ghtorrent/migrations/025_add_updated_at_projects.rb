require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'


Sequel.migration do

  up do
    puts 'Adding column updated_at to table projects'
    add_column :projects, :updated_at, DateTime,
               :null => false, :default=>Sequel::CURRENT_TIMESTAMP

    puts 'Adding default value to updated_at'
    self.transaction(:rollback => :reraise, :isolation => :repeatable) do
      self << "update projects set updated_at = now()"
    end
  end

  down do
    puts 'Deleting column updated_at from table projects'
    alter_table :projects do
      drop_column :updated_at
    end
  end
end
