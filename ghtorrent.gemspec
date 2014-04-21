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
                     'ght-rm-dupl', 'ght-process-event', 'ght-get-more-commits',
                     'ght-retrieve-repo', 'ght-retrieve-user']
  s.files         = FileList['lib/**/*.rb',
                             'bin/*',
                             '[A-Z]*',
                             'spec/**/*'].to_a

  s.add_runtime_dependency 'mongo', '~> 1.9', '>= 1.9.0'
  s.add_runtime_dependency 'bson_ext', '~> 1.9', '>= 1.9.0'
  s.add_runtime_dependency 'trollop', '~> 2.0', '>= 2.0.0'
  s.add_runtime_dependency 'sequel', '~> 4.5', '>= 4.5.0'
  s.add_runtime_dependency 'bunny', '~> 1.0', '>= 1.0.0'

  s.add_development_dependency 'rspec', '~> 2.14', '>= 2.14.0'
  s.add_development_dependency 'webmock', ['~> 1.16']

  begin
    require 'changelog'
    s.post_install_message = CHANGELOG.new.version_changes
  rescue LoadError
    warn 'You have to have changelog gem installed for post install message'
  end

end
