require 'rake'
require 'rdoc/task'

task :default => [:rdoc]

desc "Run Rdoc"
Rake::RDocTask.new(:rdoc) do |rd|
#  rd.main = "README.doc"
  rd.rdoc_files.include("lib/**/*.rb")
  rd.options << "-d"
  rd.options << "-x migrations"
end
