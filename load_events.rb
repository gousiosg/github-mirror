#!/usr/bin/env ruby
#
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
require 'yaml'
require 'github-analysis'
require 'json'
require 'mongo'
require 'amqp'
require 'set'
require 'eventmachine'
require "amqp/extensions/rabbitmq"

GH = GithubAnalysis.new

events = GH.events_col

# Selectively load event types
evt_type = ARGV.shift

valid_types = ["CommitComment", "CreateEvent", "DeleteEvent", "DownloadEvent",
               "FollowEvent", "ForkEvent", "ForkApplyEvent", "GistEvent", "GollumEvent",
               "IssueCommentEvent", "IssuesEvent", "MemberEvent", "PublicEvent",
               "PullRequestEvent", "PushEvent", "TeamAddEvent", "WatchEvent"]

q = if evt_type.nil?
      {}
    else
      if valid_types.include? evt_type
        {"type" => evt_type}
      else
        puts "No valid event type #{evt_type}"
        puts "Valid event types are :"
        valid_types.each { |x| puts "\t", x, "\n" }
        exit 1
      end
    end

# Message tags await ack
awaiting_ack = SortedSet.new

AMQP.start(:host => GH.settings['amqp']['host'],
           :port => GH.settings['amqp']['port'],
           :username => GH.settings['amqp']['username'],
           :password => GH.settings['amqp']['password']) do |connection|

  channel = AMQP::Channel.new(connection)
  exchange = channel.topic(GH.settings['amqp']['exchange'],
                           :durable => true, :auto_delete => false)

  # Num events read
  from = 0

  # Read next 1000 events and publish them on the queue
  read_and_publish = Proc.new {
    events.find(q, :skip => from, :limit => from + 1000).each do |e|
      msg = e.json
      key = "evt.%s" % e['type']
      exchange.publish msg, :persistent => true, :routing_key => key
      from += 1
      puts "Publish event.id = #{e['id']} event.type = #{e['type']} (#{from} total)"
      awaiting_ack << from
    end
  }

  # Remove acknowledged or failed msg tags from the queue
  # Trigger more messages to be read when
  publisher_event = Proc.new { |ack|
    if ack.multiple == true then
      awaiting_ack.delete_if { |x| x <= ack.delivery_tag }
    else
      awaiting_ack.delete ack.delivery_tag
    end

    if awaiting_ack.size == 0 then
      EventMachine.next_tick do
        read_and_publish.call
      end
    end
  }

  # What to do when the user hits INT or QUIT buttons
  show_stopper = Proc.new {
    connection.close { EventMachine.stop }
  }

  # Await publisher confirms
  channel.confirm_select

  # Callback when confirms have arrived
  channel.on_ack do |ack|
    puts "ACK: tag = #{ack.delivery_tag}, multiple = #{ack.multiple}, wait = #{awaiting_ack.size}"
    publisher_event.call(ack)
  end

  # Callback when confirms failed.
  channel.on_nack do |nack|
    puts "NACK: tag = #{nack.delivery_tag}, multiple = #{nack.multiple}, wait = #{awaiting_ack.size}"
    publisher_event.call(nack)
  end

  # Signal handlers
  Signal.trap('INT', show_stopper)
  Signal.trap('TERM', show_stopper)

  # Trigger start processing
  EventMachine.add_timer(0.1) do
    read_and_publish.call
  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
