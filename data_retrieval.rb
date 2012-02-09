#!/usr/bin/env ruby

require 'rubygems'
require 'amqp'
require 'github-analysis'
require 'json'
require 'pp'

GH = GithubAnalysis.new

# Graceful exit
Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

def parse msg
  JSON.parse(msg)
end

def PushEvent evt
  api_version = GH.settings['mirror']['commits']['apiversion']

  data = parse evt
  data['payload']['commits'].each do |c|
    url = c['url'].split(/\//)
    if api_version == 2
      GH.get_commit_v2 url[4], url[5], url[7]
    else
      GH.get_commit_v3 url[4], url[5], url[7]
    end
  end

end

def WatchEvent evt
  data = parse evt
  user = data['actor']['login']
  GH.get_watched user
end

handlers = ['PushEvent', 'WatchEvent']

AMQP.start(:host => GH.settings['amqp']['host'],
           :username => GH.settings['amqp']['username'],
           :password => GH.settings['amqp']['password']) do |connection|

    channel  = AMQP::Channel.new(connection, :prefetch => 5)
    exchange = channel.topic(GH.settings['amqp']['exchange'],
                             :durable => true, :auto_delete => false)

    handlers.each { |h|
      queue = channel.queue("#{h}s", {:durable => true}) \
                     .bind(exchange, :routing_key => "evt.#{h}")

      GH.log.info("Binding handler #{h} to routing key evt.#{h}")

      queue.subscribe(:ack => true) do |headers, msg|
        begin
          send(h, msg)
        rescue Exception => e
          pp JSON.parse(msg)
          GH.log.error e
        ensure
          headers.ack
        end
      end
    }
end