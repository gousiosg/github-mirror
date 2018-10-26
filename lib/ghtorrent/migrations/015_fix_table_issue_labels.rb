require 'sequel'

Sequel.migration do
  up do
    puts "Fixing table issue_labels"

    #alter_table :issue_labels do
    #  drop_constraint 'issue_labels_ibfk_1'
    #  drop_constraint 'issue_labels_ibfk_2'
    #  drop_column :repo_id
    #  drop_column :ext_ref_id
    #  drop_column :label_id
      #add_foreign_key :label_id, :repo_labels
      #add_foreign_key :issue_id, :issues
      #add_primary_key ([:issue_id, :label_id])
    #end

    drop_table :issue_labels
    create_table :issue_labels do
      foreign_key :label_id, :repo_labels
      foreign_key :issue_id, :issues
      primary_key [:issue_id, :label_id]
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
