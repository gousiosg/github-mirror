require 'rake'

Gem::Specification.new do |s|
  s.name         = 'ghtorrent'
  s.version      = '0.1'
  s.date         = '2012-05-02'
  s.summary      = 'Mirror and process Github data'
  s.description  = 'A library and a collection of associated programs
                    to mirror and process Github data'
  s.authors      = ["Georgios Gousios", "Diomidis Spinellis"]
  s.email        = 'gousiosg@gmail.com'
  s.homepage     = 'https://github.com/gousiosg/github-mirror'
  s.rdoc_options = ["--charset=UTF-8"]
  s.executables  = ['ght-data-retrieval', 'ght-load', 'ght-mirror-events',
                    'ght-periodic-dump', 'ght-rm-dupl', 'ght-torrent-index']
  s.files = [
    'config.yaml.tmpl',
    'extensions.yaml',
    'README.md',
    'VERSION',
    'ghtorrent.spec',
    'bin/ght-data-retrieval',
    'bin/ght-load',
    'bin/ght-mirror-events',
    'bin/ght-periodic-dump',
    'bin/ght-rm-dupl',
    'bin/ght-torrent-index'
  ]

  s.files << FileSet('lib/*')

  s.add_runtime_dependency "amqp", ['>= 0.9']
  s.add_runtime_dependency "mongo", ['>= 1.6']
  s.add_runtime_dependency "bson_ext", ['>= 1.6']
  s.add_runtime_dependency "json", ['>= 1.6']
  s.add_runtime_dependency "trollop", ['>= 1.16']
end
