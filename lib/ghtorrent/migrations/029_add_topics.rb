require 'sequel'
require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do

  up do
    puts 'Adding topic_categories'
    create_table :topic_categories do
      primary_key :topic_id
      String :topic_name, :size => 36, :null => false, index: {unique: true}
    end

    puts 'Adding topic_mappings'
    create_table :topic_mappings do
      foreign_key :topic_id, :topic_categories
      foreign_key :project_id, :projects
      primary_key [:topic_id, :project_id]
    end

  end

  down do
    puts 'Dropping table topic_categories'
    drop_table :topic_categories
    puts 'Dropping table topic_mappings'
    drop_table :topic_mappings
  end
end
