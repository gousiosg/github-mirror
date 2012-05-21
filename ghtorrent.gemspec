require 'rake'

ts = `git log --date=raw lib/ghtorrent.rb |grep Date|head|tr -s ' '|cut -f2 -d' '|head -n 1`
date = Time.at(ts.to_i).strftime("%Y-%m-%d")

ver = `cat lib/ghtorrent.rb |grep VERSION|cut -f2 -d'='`.strip

Gem::Specification.new do |s|
  s.name         = 'ghtorrent'
  s.version      = ver
  s.date         = date
  s.summary      = 'Mirror and process Github data'
  s.description  = 'A library and a collection of associated programs
                    to mirror and process Github data'
  s.authors      = ["Georgios Gousios", "Diomidis Spinellis"]
  s.email        = 'gousiosg@gmail.com'
  s.homepage     = 'https://github.com/gousiosg/github-mirror'
  s.rdoc_options = ["--charset=UTF-8"]
  s.executables  = ['ght-data-retrieval', 'ght-mirror-events']
                  # 'ght-load','ght-periodic-dump', 'ght-rm-dupl',
                  # 'ght-torrent-index']
  s.files        = FileList['lib/**/*.rb',
                             'bin/*',
                             '[A-Z]*',
                             'test/**/*'].to_a

  s.add_runtime_dependency "amqp", ['>= 0.9']
  s.add_runtime_dependency "mongo", ['>= 1.6']
  s.add_runtime_dependency "bson_ext", ['>= 1.6']
  s.add_runtime_dependency "json", ['>= 1.6']
  s.add_runtime_dependency "trollop", ['>= 1.16']
  s.add_runtime_dependency "sequel", ['>= 3.35']
  s.add_runtime_dependency "sqlite3-ruby", ['>= 1.3.2']
  s.add_runtime_dependency "daemons", ['>= 1.1.8']
end
