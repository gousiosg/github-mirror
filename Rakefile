require 'rake'
require 'rdoc/task'
require 'rake/testtask'
require 'byebug'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.libs << 'lib/ghtorrent'
  t.test_files = FileList['test/*_test.rb', 'test/*/*_test.rb']
end

desc "Run tests"

task :default => [:rdoc]

desc "Run Rdoc"
Rake::RDocTask.new(:rdoc) do |rd|
  #  rd.main = "README.doc"
  rd.rdoc_files.include("lib/**/*.rb")
  rd.options << "-d"
  rd.options << "-x migrations"
end
