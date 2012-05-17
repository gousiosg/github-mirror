require 'sequel'

Sequel.migration do
  up do
    alter_table :users do
      add_column :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    end

    alter_table :projects do
      add_column :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    end

    alter_table :commits do
      add_column :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    end

    alter_table :followers do
      add_column :ext_ref_id, String, :null => false, :size => 24, :default => "0"
    end
  end

  down do
    alter_table :users do
      drop_column :ext_ref_id
    end

    alter_table :projects do
      drop_column :ext_ref_id
    end

    alter_table :commits do
      drop_column :ext_ref_id
    end

    alter_table :followers do
      drop_column :ext_ref_id
    end
  end
end

