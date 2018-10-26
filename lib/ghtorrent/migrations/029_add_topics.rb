require 'sequel'

Sequel.migration do

  up do
    puts 'Adding table project_topics'
    create_table :project_topics do
      foreign_key :project_id, :projects
      String :topic_name, :size => 36
      DateTime :created_at, :null => false,
               :default => Sequel::CURRENT_TIMESTAMP
      TrueClass :deleted, :null => false, :default => false

      primary_key [:project_id, :topic_name]
    end

  end

  down do
    puts 'Dropping table project_topics'
    drop_table :project_topics
  end
end
