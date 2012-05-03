#!/usr/bin/env ruby
#

require 'rubygems'
require 'mongo'
require 'amqp'
require 'yaml'
require File.dirname(__FILE__) + '/../ghtorrent'

GH = GHTorrent.new

# Load extensions file to a hash indexed by extension
extensions = Hash.new
yml = YAML.load_file 'extensions.yaml'
yml.each_key do |key|
    values = yml[key]
    values.each do |value|
        extensions[value] = key
    end
end

# Treat languages with header files specially
clangs = Array.new
clangs << yml["c"].select{|x| x != "h"}
clangs << yml["cpp"].select{|x| x != "h"}
clangs << yml["objc"].select{|x| x != "h"}

# Start message processing loop
Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

AMQP.start(:host => GH.settings['amqp']['host'],
           :port => GH.settings['amqp']['port'],
           :username => GH.settings['amqp']['username'],
           :password => GH.settings['amqp']['password']) do |connection|

  channel = AMQP::Channel.new(connection, :prefetch => 1)
  exchange = channel.topic(GH.settings['amqp']['exchange'],
                           :durable => true, :auto_delete => false)

  queue = channel.queue("commits", {:durable => true}) \
                 .bind(exchange, :routing_key => "commit.#")

  i = 0
  queue.subscribe(:ack => true) do |headers, msg|

    result = GH.commits_col.find({'commit.id' => "#{msg}"})
    i += 1

    # Commit in queue, but not in mongo
    unless result.has_next?
      puts "Error getting result for commit id #{msg}"
      next
    end

    # Each resultset should only contain a single result
    commit = result.to_a[0]

    # Github diff JSON format: http://develop.github.com/p/commits.html
    project = commit["commit"]["url"].split(/\//)[2]
    puts "Project: #{project}"

    # Count number of lines in each diff. We only analyse modified
    # file diffs as github does not report diffs for added or deleted files
    # Results are post-processed in order to
    results = Array.new
    commit["commit"]["modified"].each do |diff|

      # Github does not provide diffs for binary files and seems to be employing
      # a cutoff filter based on diff size, for very large diffs
      unless diff["diff"]
        puts "File #{diff["filename"]} is binary or diff too big"
        next
      end
      added = removed = 0
      diff["diff"].lines.collect do |l|
        case l[0, 1]
          when "+"; then added += 1
          when "-"; then removed += 1
        end
      end

      parts = diff["filename"].split(/\./)

      if parts.length == 1
        puts "Path does not contain an extension: #{diff["filename"]}"
        next
      end

      ext = parts[-1]

      # Save result
      entry = {'commit' => commit['commit']['id'], 'ext' => ext,
               'add' => added, 'del' => removed}

      results << entry
      puts "File: #{diff["filename"]}, ext: #{ext} (+#{added}, -#{removed})"

    end unless not commit["commit"]["modified"]

    # Resolve extensions, treat .h specially. The convention is that
    # the language is set to that that most (C-lang like) files included in
    # the commit. If the commits includes just one file ending in .h, then
    # the language defaults to C.

    not_has_h = results.find{|h| h['ext'] == "h"}.nil?

    results = unless not_has_h
                lang = results.group_by { |x| x['ext'] }.max_by { |x| x[1].size }[0]
                lang = "c" if lang == "h"
                puts "Mapping extension .h to .#{lang}"
                results.map { |x| x['ext'] = lang; x }
              else
                results
              end

    results = results.inject(Hash.new) {|acc, x|
      lang = extensions[x['ext']]
      lang = "Unknown" if lang.nil?
      modified = x['add'] + x['del']
      if acc[lang].nil?
        acc[lang] = modified
      else
        acc[lang] += modified
      end
      acc
    }

    results.each{|k,v|
      puts "Lang: #{k}, Lines: #{v}"
    }

    headers.ack
  end
end
AMQP.stop{ EM.stop }

#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent: