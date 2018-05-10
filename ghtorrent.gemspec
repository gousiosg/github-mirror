require 'rake'
require File.expand_path('../lib/version', __FILE__)

Gem::Specification.new do |s|
  s.name          = 'ghtorrent'
  s.version       = GHTorrent::VERSION
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
  s.files         = FileList['lib/**/*.rb',
                             'bin/*',
                             '[A-Z]*',
                             'lib/ghtorrent/country_codes.txt'].to_a
  s.required_ruby_version = '~> 2.0'

  s.add_runtime_dependency 'mongo', '~> 2.4', '>= 2.4.3'
  s.add_runtime_dependency 'trollop', '~> 2.0', '>= 2.0.0'
  s.add_runtime_dependency 'sequel', '~> 4.5', '>= 4.5.0'
  s.add_runtime_dependency 'bunny', '~> 2.3', '>= 2.3.0'

  s.add_development_dependency 'influxdb', '0.3.5'

  s.add_development_dependency "minitest", "~> 4.7.3"
  s.add_development_dependency 'm', '~> 1.5.0'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'simplecov-rcov'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'factory_girl'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'

  begin
    require 'changelog'
    s.post_install_message = CHANGELOG.new.version_changes
  rescue LoadError
    warn 'You have to have changelog gem installed for post install message'
  end

end
