#!/usr/bin/env ruby

require 'rubygems'
require 'amqp' #gem install amqp -v 0.7.1 <--need this version
require 'github-analysis'

settings = YAML::load_file "config.yaml"
github = GithubAnalysis.new

Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

AMQP.start(:host => settings['amqp']['host'],
           :username => settings['amqp']['username'],
           :password => settings['amqp']['password']) do |connection|

    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic("commits", opts = {:durable => true})
    queue = channel.queue("commits", {:durable => true}).bind(exchange, :routing_key => "commits.#")
    queue.subscribe do |headers, msg|
      user, repo, sha = msg.strip.split(/ /)
      github.get_commit user, repo, sha
    end
end
