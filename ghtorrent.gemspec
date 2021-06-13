Gem::Specification.new do |s|
  s.name          = 'ghtorrent'
  s.version       = '0.12.1'
  s.date          = Time.now.strftime('%Y-%m-%d')
  s.summary       = 'Mirror and process Github data'
  s.description   = 'A library and a collection of associated programs
                    to mirror and process Github data'
  s.authors       = ['Georgios Gousios', 'Diomidis Spinellis']
  s.email         = 'gousiosg@gmail.com'
  s.homepage      = 'https://github.com/gousiosg/github-mirror'
  s.licenses      = ['BSD-2-Clause']
  s.require_paths = ['lib']
  s.rdoc_options  = ['--charset=UTF-8']
  s.executables   = ['ght-data-retrieval', 'ght-mirror-events', 'ght-load',
                     'ght-retrieve-repo', 'ght-retrieve-user',
                     'ght-retrieve-repos', 'ght-retrieve-users',
                     'ght-mass-harvester']
  s.files         = Dir.glob(['lib/**/*.rb',
                             'bin/*',
                             '[A-Z]*',
                             'lib/ghtorrent/country_codes.txt'])
  s.required_ruby_version = '~> 2.5'

  s.add_runtime_dependency 'mongo', '~> 2.6'
  s.add_runtime_dependency 'trollop', '~> 2.0', '>= 2.0.0'
  s.add_runtime_dependency 'sequel', '~> 4.5', '>= 4.5.0'
  s.add_runtime_dependency 'bunny', '~> 2.3', '>= 2.3.0'

  s.add_development_dependency 'sqlite3', '1.3.13'
  s.add_development_dependency 'influxdb', '0.3.5'

end
