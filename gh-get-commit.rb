#!/usr/bin/env ruby

require 'rubygems'
require 'amqp' #gem install amqp -v 0.7.1 <--need this version
require 'github-analysis'

github = GithubAnalysis.new

api_method = "get_commit_v#{github.settings['mirror']['commits']['apiversion']}"

Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

AMQP.start(:host => github.settings['amqp']['host'],
           :username => github.settings['amqp']['username'],
           :password => github.settings['amqp']['password']) do |connection|

    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic("commits", opts = {:durable => true})
    queue = channel.queue("commits", {:durable => true}).bind(exchange, :routing_key => "commits.#")
    queue.subscribe do |headers, msg|
      user, repo, sha = msg.strip.split(/ /)
      github.send(api_method, user, repo, sha)
    end
end
