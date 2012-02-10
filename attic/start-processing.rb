#!/usr/bin/env ruby
#

require 'rubygems'
require 'mongo'
require 'amqp' #gem install amqp -v 0.7.1 <--need this version
require 'yaml'
require 'json'
require 'set'
require 'github-analysis'

settings = YAML::load_file "config.yaml"

# Mongo cmd-line client commands
# db.commits.remove({error: {'$exists': true}})
# db.createcollection('unique_commits')
# db.commits.mapReduce(map, reduce, {out: 'unique_commits'});
# map = function() {emit(this.commit.id, 1)}
# reduce = function(key, values) {return key;}
# db.commits.mapReduce(map, reduce, {out: 'unique_commits'});

#puts "Running map/reduce to get unique commits...:"
#$map="function() {if (!this.hasOwnProperty('error')) emit(this.commit.id, 1)}"
#$reduce="function(key, values) {return key;}"
#$results = analysis.commits_col.map_reduce($map, $reduce,
#                               {:out=>{"replace"=> "mrtemp"}})\
#                   .find({}, :fields =>['value'])

msgkey = case ARGV[0]
         when "commitlength" then "commitlength"
         else "unknown"
         end

Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

AMQP.start(:host => settings['amqp']['host'],
           :username => settings['amqp']['username'],
           :password => settings['amqp']['password']) do |connection|
    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic("mapreduce", {:durable => true})

    ts = Time.now.to_i
    msg = Hash.new

    puts "Getting commits list..."
    i = 0
    github = GithubAnalysis.new
    github.get_commit_ids.each do |x|
        msg['date'] = ts
        msg['commit'] = x
        exchange.publish(msg.to_json, :persistent => true,
                                      :routing_key => "#{msgkey}.#{i}")
        i += 1
        print "\rPublishing #{i} messages"
    end
    
    AMQP.stop {EM.stop}
end

