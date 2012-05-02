#!/usr/bin/env ruby

# Copyright 2012 Georgios Gousios <gousiosg@gmail.com>
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#   1. Redistributions of source code must retain the above
#      copyright notice, this list of conditions and the following
#      disclaimer.
#
#   2. Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials
#      provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.


require 'rubygems'
require 'amqp'
require 'github-analysis'
require 'json'
require 'pp'

GH = GithubAnalysis.new

# Graceful exit
Signal.trap('INT') { AMQP.stop { EM.stop } }
Signal.trap('TERM') { AMQP.stop { EM.stop } }

def parse msg
  JSON.parse(msg)
end

def PushEvent evt
  data = parse evt
  data['payload']['commits'].each do |c|
    url = c['url'].split(/\//)
    GH.get_commit_v2 url[4], url[5], url[7]
    GH.get_commit_v3 url[4], url[5], url[7]
  end
end

def WatchEvent evt
  data = parse evt
  user = data['actor']['login']
  GH.get_watched user, evt
end

def FollowEvent evt
  data = parse evt
  user = data['actor']['login']
  GH.get_followed user

  followed = data['payload']['target']['login']
  GH.get_followers followed
end

handlers = ['PushEvent', 'WatchEvent', 'FollowEvent']

AMQP.start(:host => GH.settings['amqp']['host'],
           :port => GH.settings['amqp']['port'],
           :username => GH.settings['amqp']['username'],
           :password => GH.settings['amqp']['password']) do |connection|

  channel = AMQP::Channel.new(connection, :prefetch => 5)
  exchange = channel.topic(GH.settings['amqp']['exchange'],
                           :durable => true, :auto_delete => false)

  handlers.each { |h|
    queue = channel.queue("#{h}s", {:durable => true}) \
                     .bind(exchange, :routing_key => "evt.#{h}")

    GH.log.info("Binding handler #{h} to routing key evt.#{h}")

    queue.subscribe(:ack => true) do |headers, msg|
      tries = 0
      while tries < 3
        begin
          send(h, msg)
          break
        rescue Exception => e
          tries += 1
          pp JSON.parse(msg)
          GH.log.error e
        end
        GH.log.warn "Error processing request, retrying (attempt = #{tries})"
      end
      headers.ack
    end
  }
end
