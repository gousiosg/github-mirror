require 'sequel'

Sequel.migration do

  up do
    puts 'Adding table project_languages'

    create_table :project_languages do
      foreign_key :project_id, :projects, :null => false
      String :language, :null => false
      Integer :bytes, :null => false, :default => 0
      DateTime :created_at, :null => false,
               :default => Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    puts 'Dropping table project_languages'
    drop_table :project_languages
  end
end
