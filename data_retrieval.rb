#!/usr/bin/env ruby

require 'rubygems'
require 'amqp'
require 'github-analysis'
require 'optparse'

GH = GithubAnalysis.new

# Graceful exit
Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

def PushEvent evt
  puts "PushEvent"
end

def WatchEvent evt
  puts "WatchEvent"
end

handlers = ['PushEvent', 'WatchEvent']

AMQP.start(:host => GH.settings['amqp']['host'],
           :username => GH.settings['amqp']['username'],
           :password => GH.settings['amqp']['password']) do |connection|

    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic(GH.settings['amqp']['exchange'],
                             :durable => true, :auto_delete => false)

    handlers.each { |h|
      queue = channel.queue("#{h}s", {:durable => true}) \
                     .bind(exchange, :routing_key => "evt.#{h}")

      GH.log.info("Binding handler #{h} to routing key evt.#{h}")

      queue.subscribe do |headers, msg|
        send(h, msg)
      end
    }
end