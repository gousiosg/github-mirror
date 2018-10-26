require 'sequel'

Sequel.migration do
  up do

    puts("Adding organization descriminator field to table users")

    alter_table :users do
      add_column :type, String, :null => false, :default => 'USR'
      add_constraint(:type_allowed_values, :type => %w[USR ORG])
    end

    puts("Updating users with default values")
    transaction(:rollback => :reraise, :isolation => :committed) do
      self[:users].update(:type => "USR")
    end

    puts("Creating table organization-members")

    create_table :organization_members do
      foreign_key :org_id, :users, :null => false
      foreign_key :user_id, :users, :null => false
      primary_key [:org_id, :user_id]
      DateTime :created_at, :null => false,
               :default => Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    puts("Droping table organization-members")
    drop_table :organization_members

    puts("Droping organization descriminator field to table users")
    alter_table :users do
      drop_column :type
    end
  end
end