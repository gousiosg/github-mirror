require 'sequel'

def create_schema(db)

  puts("Creating table user")
  db.create_table :user do
    primary_key :id
    String :login
    String :name
    String :company, :null => true
    String :location
    String :email, :null => true, :unique => true
    TrueClass :hireable, :null => true
    String :bio, :null => true
    Time :created_at
  end

  puts("Creating table project")
  db.create_table :project do
    primary_key :id
    String :url
    foreign_key :owner, :user
    String :name
    String :description
    String :language
    Time :created_at
  end

  puts("Creating table commit")
  db.create_table :commit do
    primary_key :id
    String :sha, :size => 40, :unique => true
    String :message
    foreign_key :login_id, :user
    foreign_key :author_id, :user
    foreign_key :committer_id, :user
  end

  puts("Creating table commit_parents")
  db.create_table :commit_parents do
    foreign_key :commit_id, :commit
    foreign_key :parent_id, :commit
    primary_key [:commit_id, :parent_id]
  end

end