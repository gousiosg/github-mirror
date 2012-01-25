#!/usr/bin/env ruby
#

require 'rubygems'
require 'yaml'
require 'eventmachine'
require 'github-analysis'

settings = YAML::load_file "config.yaml"
github = GithubAnalysis.new

EventMachine.run do
  EventMachine.add_periodic_timer(1) do
      events = github.api_request "https://api.github.com/events"
      events.each do |e|
        next if e['type'] != "WatchEvent"
        if github.events_col.find({'id' => e['id']}).has_next? then
          puts "Already got #{e['id']}"
        else
          github.events_col.insert(e)
          puts "Added #{e['id']}"
        end
      end
  end
end

