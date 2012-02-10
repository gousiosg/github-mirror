#!/usr/bin/env ruby
#

require 'rubygems'
require 'amqp'
require 'yaml'

settings = YAML::load_file "config.yaml"

AMQP.start(:host => settings['amqp']['host'],
           :username => settings['amqp']['username'],
           :password => settings['amqp']['password']) do |connection|

    # Send Connection.Close on Ctrl+C
    trap(:INT) do
        unless connection.closing?
            connection.close { exit! }
        end
    end

    channel  = AMQP::Channel.new(connection)
    exchange = channel.topic("commits", {:durable => true})

    File.open(ARGV[0], 'r') do |f|  
        while line = f.gets 
            x = line.split(/ /)

            if not x[2].scan(/.*#/).empty? then
                x[2] = x[2][0, x[2].index('#')]
            end

            if not x[2].match(/[a-f0-9]{40}$/) then
                puts "Ignoring #{x[2]}"
                next 
            end

            puts "Adding #{x[2]}"
            msg = "#{x[0]} #{x[1]} #{x[2]}"

            exchange.publish( msg, :persistent => true,
                             :routing_key => "commits.#{x[2]}")
        end  
    end
    AMQP.stop { EM.stop }
end
