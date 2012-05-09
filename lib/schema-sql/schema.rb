require 'sequel'

def create_schema(db)

  puts("Creating table user")
  db.create_table :users do
    primary_key :id
    String :login, :unique => true, :null => false
    String :name
    String :company, :null => true
    String :location, :null => true
    String :email, :null => true, :unique => true
    TrueClass :hireable, :null => true
    String :bio, :null => true
    Time :created_at, :null => false
  end

  puts("Creating table project")
  db.create_table :projects do
    primary_key :id
    String :url
    foreign_key :owner_id, :users
    String :name, :null => false
    String :description
    String :language
    Time :created_at, :null => false
  end

  puts("Creating table commit")
  db.create_table :commits do
    primary_key :id
    String :sha, :size => 40, :unique => true
    foreign_key :author_id, :users
    foreign_key :committer_id, :users
    Time :created_at, :null => false
  end

  puts("Creating table commit_parents")
  db.create_table :commit_parents do
    foreign_key :commit_id, :commits, :null => false
    foreign_key :parent_id, :commits, :null => false
    primary_key [:commit_id, :parent_id]
  end

end