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

  s.add_development_dependency "minitest", '~> 5.0'
  s.add_development_dependency 'm',  '~> 1.5', '>= 1.5.0' 
  s.add_development_dependency 'simplecov', '~> 0.16'
  s.add_development_dependency 'simplecov-rcov', '~> 0.2'
  s.add_development_dependency 'mocha', '~> 1.10'
  s.add_development_dependency 'factory_girl', '~> 4.1'
  s.add_development_dependency 'faker', '~> 2.9'
  s.add_development_dependency 'byebug', '~> 10.0'
  s.add_development_dependency 'vcr', '~> 4'
  s.add_development_dependency 'webmock', '~> 3.7'
  s.add_development_dependency 'minitest-around', '~> 0.5'
  s.add_development_dependency 'rake', '~> 13'

end
