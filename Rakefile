require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

task :default => [:spec, :rdoc]

desc "Run basic tests"
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/*_test.rb'
  t.verbose = true
  t.warning = true
end

desc "Run Rdoc"
Rake::RDocTask.new(:rdoc) do |rd|
#  rd.main = "README.doc"
  rd.rdoc_files.include("lib/**/*.rb")
  rd.options << "-d"
  rd.options << "-x migrations"
end
