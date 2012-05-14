require 'sequel'

Sequel.migration do
  up do
    alter_table :followers do
      add_column :created_at, :Time, :null => false, :default => Time.now
    end
  end

  down do
    alter_table :followers do
      drop_column :created_at
    end
  end
end