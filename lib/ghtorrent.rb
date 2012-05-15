require 'ghtorrent/command'

Dir[File.dirname(__FILE__) + "/schema-sql/**/*.rb"].each do |file|
  require file
end