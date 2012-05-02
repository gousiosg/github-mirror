require 'rake'

Gem::Specification.new do |s|
  s.name         = 'ghtorrent'
  s.version      = '0.1'
  s.date         = '2012-05-2'
  s.summary      = 'ghtorrent'
  s.description  = 'Scripts and library to mirror and process github data'
  s.authors      = ["Georgios Gousios", "Diomidis Spinellis"]
  s.email        = 'gousiosg@gmail.com'
  s.homepage     = 'https://github.com/gousiosg/github-mirror'
  s.rdoc_options = ["--charset=UTF-8"]
  s.executables  = FileList['bin/*']
  s.files        = FileList['lib/**/*.rb',
                           'bin/*',
                           '[A-Z]*',
                           'test/**/*'].to_a
end
