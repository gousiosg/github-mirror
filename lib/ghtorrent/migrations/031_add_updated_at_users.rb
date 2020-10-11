require 'sequel'

Sequel.migration do

  up do
    puts 'Adding column updated_at to table users'

    if defined?(Sequel::SQLite)
      add_column :users, :updated_at, DateTime,
                 :null => false, :default => 56400
    else
      add_column :users, :updated_at, DateTime,
                 :null => false, :default => Sequel::CURRENT_TIMESTAMP
    end

    puts 'Adding default value to updated_at'
    self.transaction(:rollback => :reraise, :isolation => :repeatable) do
      if defined?(Sequel::SQLite)
        self << "update users set updated_at = CURRENT_TIMESTAMP;"
      elsif defined?(Sequel::Postgres)
        self << "update users set updated_at = now();"
      elsif defined?(Sequel::MySQL)
        self << "update users set updated_at = now();"
      else
        raise StandardError("Don't know how to set default value")
      end
    end
  end

  down do
    puts 'Deleting column updated_at from table users'
    alter_table :users do
      drop_column :updated_at
    end
  end
end
