require 'sequel'

Sequel.migration do

  up do
    puts 'Add column fake to users'
      add_column :users, :fake, TrueClass, :null => false, :default => false

    if self.database_type == :mysql
      self.transaction(:rollback => :reraise, :isolation => :committed) do
        self << "update users
                 set fake = '1'
                 where CAST(users.login AS BINARY) regexp '[A-Z]{8}'
                  and not exists (select * from pull_request_history where users.id = actor_id)
                  and not exists (select * from issue_events where actor_id = users.id)
                  and not exists (select * from project_members where users.id = user_id)
                  and not exists (select * from issues where reporter_id=users.id )
                  and not exists (select * from issues where assignee_id=users.id )
                  and not exists (select * from organization_members where user_id = users.id);"
      end
    end
  end

  down do
    puts 'Drop column fake from users'
    alter_table :users do
      drop_column :fake
    end
  end
end
