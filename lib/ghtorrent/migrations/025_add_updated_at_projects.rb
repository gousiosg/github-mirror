require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'


Sequel.migration do

  up do
    puts 'Adding column updated_at to table projects'

    if defined?(Sequel::SQLite)
      add_column :projects, :updated_at, DateTime,
                 :null => false, :default => 0
    else
      add_column :projects, :updated_at, DateTime,
                 :null => false, :default => Sequel::CURRENT_TIMESTAMP
    end

    puts 'Adding default value to updated_at'
    self.transaction(:rollback => :reraise, :isolation => :repeatable) do
      if defined?(Sequel::MySQL)
        self << "update projects set updated_at = now();"
      elsif defined?(Sequel::Postgres)
        self << "update projects set updated_at = now();"
      elsif defined?(Sequel::SQLite)
        self << "update projects set updated_at = CURRENT_TIMESTAMP;"
      else
        raise StandardError("Don't know how to set default value")
      end
    end
  end

  down do
    puts 'Deleting column updated_at from table projects'
    alter_table :projects do
      drop_column :updated_at
    end
  end
end
