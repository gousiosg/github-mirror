require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do
    puts "Fixing table issue_labels"

    alter_table :issue_labels do
      drop_column :repo_id
      drop_column :ext_ref_id
      add_foreign_key :issue_id, :issues
      add_primary_key ([:issue_id, :label_id])
    end
  end

  down do
    alter_table :issue_labels do
      drop_constraint :primary_key
      drop_column :issue_id
      add_foreign_key :repo_id, :projects
    end
  end
end
