require 'sequel'

Sequel.migration do

  up do

    puts 'Adding column forked_from in table projects'
    alter_table :projects do
      add_foreign_key :forked_from, :projects, :null => true
    end

    puts 'Migrating data from forks to project(forked_from)'
    self.transaction(:rollback => :reraise, :isolation => :committed) do
      self[:projects].each do |p|
        fork = self[:forks].first(:forked_project_id => p[:id])
        unless fork.nil?
          source = self[:projects].first(:id => fork[:forked_from_id])
          self[:projects].filter(:id => p[:id]).update(:forked_from => source[:id])
          puts "#{p[:owner_id]}/#{p[:name]} is forked from #{source[:owner_id]}/#{source[:name]}"
        end
      end
    end
  end

  down do
    alter_table :projects do
      drop_column :forked_from
    end
  end
end