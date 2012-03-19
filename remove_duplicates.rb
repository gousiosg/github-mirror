#!/usr/bin/env ruby

require 'rubygems'
require 'set'
require 'mongo'
require 'github-analysis'

GH = GithubAnalysis.new

per_col = {
    :commits => {
        :unq => "commits.id",
        :col => GH.commits_col,
        :rm  => ""
    },
    :events => {
        :unq => "id",
        :col => GH.events_col,
        :rm  => ""
    }
}

which = case ARGV[0]
          when "commits" then :commits
          when "events" then :events
          else GH.log.error("Not a known collection name: #{ARGV[0]}")
      end

data = Hash.new
processed = 0

per_col[which][:col].find({}, :fields => per_col[which][:unq]).each { |r|
  data[r["_id"].to_s] = [] if data[r["_id"]].nil?
  data[r["_id"].to_s] << r[per_col[which][:unq]]
  processed += 1
  print "\rProcessed #{processed} records"
}

puts "Loaded #{data.size} values, cleaning"

duplicates = data.select{|k,v| v.size > 1}

puts "Found #{duplicates.size} duplicates, the following:"

duplicates.each{|k, v| puts k, "->", v}