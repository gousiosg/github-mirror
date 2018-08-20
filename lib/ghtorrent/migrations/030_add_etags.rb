require 'sequel'
require 'ghtorrent/migrations/mysql_defaults'

Sequel.migration do
  up do
    puts 'Adding table etags'
    create_table :etags do
      String :base_url, unique: true, null: false
      String :etag, size: 40, null: false
      Integer :page_no, null: false, default: 1
      String :response, text: true
      Integer :used_count, default: 0
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    puts 'Dropping table etags'
    drop_table :etags
  end
end
