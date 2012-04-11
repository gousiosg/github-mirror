require 'rake'

Gem::Specification.new do |s|
  s.name         = 'github-mirror'
  s.version      = '0.1'
  s.date         = '2012-04-11'
  s.summary      = 'github-mirror'
  s.description  = 'Scripts and library to mirror and process github data'
  s.authors      = ["Georgios Gousios"]
  s.email        = 'gousiosg@gmail.com'
  s.homepage     = 'https://github.com/gousiosg/github-mirror'
  s.rdoc_options = ["--charset=UTF-8"]
  s.files        = FileList['lib/**/*.rb',
                           'bin/*',
                           '[A-Z]*',
                           'test/**/*'].to_a
end