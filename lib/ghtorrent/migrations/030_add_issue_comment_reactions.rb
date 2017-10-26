require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do
    puts 'Adding reaction columns to issue_comments'
    alter_table :issue_comments do
      add_column :like, Integer, :null => false, :default => 0
      add_column :dislike, Integer, :null => false, :default => 0
      add_column :laugh, Integer, :null => false, :default => 0
      add_column :confused, Integer, :null => false, :default => 0
      add_column :laugh, Integer, :null => false, :default => 0
      add_column :heart, Integer, :null => false, :default => 0
      add_column :hooray, Integer, :null => false, :default => 0
    end
  end

  down do
    puts 'Dropping reaction columns from issue_comments'
    drop_column :like
    drop_column :dislike
    drop_column :laugh
    drop_column :confused
    drop_column :laugh
    drop_column :heart
    drop_column :hooray
  end
end
