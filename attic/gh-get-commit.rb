#!/usr/bin/env ruby

require 'rubygems'
require 'amqp'
require 'ghtorrent'
require 'optparse'

github = GHTorrent.new

# Find out which api version to use for retrieving the commits
api_version = github.settings['mirror']['commits']['apiversion']

ver = ARGV.shift.to_i

if ![2,3].include?(ver) then
  puts "#{ver} is not a valid API version number, using default #{api_version}"
else
  api_version = ver
end

api_method = "get_commit_v#{api_version}"

Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

# Event loop
AMQP.start(:host => github.settings['amqp']['host'],
           :username => github.settings['amqp']['username'],
           :password => github.settings['amqp']['password']) do |connection|

    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic(github.settings['amqp']['exchange'],
                             :durable => true, :auto_delete => false)

    queue = channel.queue("commits-v#{api_version}",
                          {:durable => true}).bind(exchange)

    queue.subscribe do |headers, msg|
      user, repo, sha = msg.strip.split(/ /)
      github.send(api_method, user, repo, sha)
    end
end
