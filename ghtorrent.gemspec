require 'rake'
require File.expand_path('../lib/version', __FILE__)

ts = `git log --date=raw lib/ghtorrent.rb |grep Date|head|tr -s ' '|cut -f2 -d' '|head -n 1`
date = Time.at(ts.to_i).strftime("%Y-%m-%d")

Gem::Specification.new do |s|
  s.name          = 'ghtorrent'
  s.version       = GHTorrent::VERSION
  s.date          = date
  s.summary       = 'Mirror and process Github data'
  s.description   = 'A library and a collection of associated programs
                    to mirror and process Github data'
  s.authors       = ["Georgios Gousios", "Diomidis Spinellis"]
  s.email         = 'gousiosg@gmail.com'
  s.homepage      = 'https://github.com/gousiosg/github-mirror'
  s.require_paths = ["lib"]
  s.rdoc_options  = ["--charset=UTF-8"]
  s.executables   = ['ght-data-retrieval', 'ght-mirror-events', 'ght-load',
                     'ght-rm-dupl', 'ght-process-event', 'ght-get-more-commits',
                     'ght-retrieve-repo', 'ght-retrieve-user']
  s.files         = FileList['lib/**/*.rb',
                             'bin/*',
                             '[A-Z]*',
                             'test/**/*'].to_a

  s.add_dependency "amqp", ['~> 1.0.0']
  s.add_dependency "mongo", ['~> 1.8.0']
  s.add_dependency "bson_ext", ['~> 1.8.0']
#  s.add_dependency "json", ['~> 1.6.']
  s.add_dependency "trollop", ['~> 2.0.0']
  s.add_dependency "sequel", ['~> 3.47']
  s.add_dependency "daemons", ['~> 1.1.0']

  begin
    require "changelog"
    s.post_install_message = CHANGELOG.new.version_changes
  rescue LoadError
    warn "You have to have changelog gem installed for post install message"
  end

end
