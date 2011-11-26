#!/usr/bin/env ruby
#

require 'rubygems'
require 'mongo'
require 'json'
require 'amqp' #gem install amqp -v 0.7.1 <--need this version
require 'yaml'
require 'github-analysis'

settings = YAML::load_file "config.yaml"

# Load extensions file to a hash indexed by extension
extensions = Hash.new
yml = YAML.load_file 'extensions.yaml'
yml.each_key do |key|
    values = yml[key]
    values.each do |value|
        extensions[value] = key
    end
end

github = GithubAnalysis.new

# Start message processing loop
Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

AMQP.start(:host => settings['amqp']['host'],
           :username => settings['amqp']['username'],
           :password => settings['amqp']['password']) do |connection|

  channel  = AMQP::Channel.new(connection)
  exchange = channel.topic("mapreduce", opts = {:durable => true})
  queue = channel.queue("mapreduce.commitlength", {:durable => true})\
                 .bind(exchange, :routing_key => "commitlength.#")

  i = 0
  queue.subscribe do |headers, msg|
    # Format is : {"date":epoch, "commit": "sha"}
    message = JSON.parse(msg)

    if github.commitlength_col.find({'commit' => "#{message["commit"]}"}).has_next? then
      puts "Already got #{message["commit"]}"
      next
    end

    result = github.commits_col.find({'commit.id' => "#{message["commit"]}"})
    i += 1

    # Commit in queue, but not in mongo
    if not result.has_next? then
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
      if not diff["diff"] then
        puts "File #{diff["filename"]} is binary or diff too big"
        next
      end
      added = removed = 0
      diff["diff"].lines.collect do |l|
        case l[0,1]
        when "+"; then added += 1 
        when "-"; then removed += 1
        end
      end

      parts = diff["filename"].split(/\./)

      if parts.length == 1 then
        puts "Path does not contain an extension: #{diff["filename"]}"
        next
      end
      
      ext = parts[-1]

      # Save result
      entry = {'commit' => commit['commit']['id'], 'ext' => ext,
               'add' => added, 'del' => removed}

      results.add entry
      puts "File: #{diff["filename"]}, Lang: #{lang} (+#{added}, -#{removed})"

    end unless not commit["commit"]["modified"]

    # Resolve extensions, treat .h specially. The convention is that
    # the language is set to that that most (C-lang like) files included in
    # the commit. If the commits includes just one file ending in .h, then
    # the language defaults to C.
    clangs = Hash.new
    results.each do |i|

      ext = i['ext']
      lang = extensions[ext]

      if ext == 'h' then
        lang = 'letssee'
      end

      if not lang then
        puts "Unknown extension #{ext}"
        next
      end

      clangs[lang] = clangs[lang] + 1 || 1
      i['lang'] = lang
      i['ext'].delete
    end

    winner = clangs.\
              map{|k, v| [k, v]}.\
              reduce([0,0]){|max, b| max = b if b[1] > max[1]; max}

    github.commitlength_col.insert(entry)

  end
  AMQP.stop{ EM.stop }
end


# m = function () {emit(this.lang, {'add':this.add, 'del':this.del}); }
# m = function () {emit(this.lang, this.add); }
# r = function (k, vals) { var added = 0; var removed = 0; var count = 0; vals.forEach(function (value) {added += value.add; removed += value.del; count += 1;}); return {'avgadded': added / count, 'avgremoved': removed / count, 'numcommits': count} }
# db.mapreduce.commitlength.mapReduce(m, r, {out : 'avg_add'})

#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
