require 'sequel'

require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do
    puts 'Adding reaction columns to issue_comments'
    alter_table :issue_comments do
      add_column :like, Integer
      add_column :dislike, Integer
      add_column :laugh, Integer
      add_column :confused, Integer
      add_column :heart, Integer
      add_column :hooray, Integer
    end
  end

  down do
    puts 'Dropping reaction columns from issue_comments'
    drop_column :like
    drop_column :dislike
    drop_column :laugh
    drop_column :confused
    drop_column :heart
    drop_column :hooray
  end
end
