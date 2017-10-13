require 'sequel'
require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do

  up do
    puts 'Adding column topics to projects'

    alter_table(:projects) do
      add_column :topics, 'text[]', :null => true, :unique => false
    end

  end

  down do
    puts 'Dropping column topics from projects'
    alter_table(:projects) do
      drop_column :topics
    end
  end
end
