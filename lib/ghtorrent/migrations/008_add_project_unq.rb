require 'sequel'

Sequel.migration do
  up do

    puts("Adding unique(name, owner) constraint to table projects")

    alter_table :projects do
      add_unique_constraint([:name, :owner_id])
    end
  end

  down do

    puts("Removing unique(name, owner) constraint from table projects")

    alter_table :projects do
      drop_unique_constraint([:name, :owner_id])
    end
  end
end