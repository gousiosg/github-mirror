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
require 'erb'
require 'set'

class GHTorrent
  def initialize(last_update)
    @last_update = last_update
    @dumps = Set.new
    @collections = Set.new
  end

  def add_dump(dump)
    @dumps << dump
  end

  def add_collection(col)
    @collections << col
  end

  # Expose private binding() method.
  def get_binding
    binding()
  end

end

class Dump
  attr_reader :torrents
  attr_reader :date
  def initialize(torrents, date)
    @torrents = torrents
    @date = date
  end
end

class Torrent
  attr_reader :url
  attr_reader :name
  attr_reader :size
  attr_reader :date
  def initialize(url, name, size, date)
    @url = url
    @name = name
    @size = size
    @date = date
  end
end

# Load the template
file = File.open("index.erb").read
rhtml = ERB.new(file)

# Open the dir to read entries from
dir = ARGV.shift

if dir.nil?
  dir = "."
end

torrents = Dir.entries("#{dir}").map do |f|

  # Go through all torrent files and extract name of
  # dumped collection and dump date
  matches = /([a-z0-9]+)-[a-z]+\.(.*)\.torrent/.match(f)
  next if matches.nil?

  # Calculate original file size
  dump = f.gsub(/.torrent/, ".tar.bz2")
  size = File.stat(File.join(dir, dump)).size / 1024 / 1024

  Torrent.new(f, matches[1], size, matches[2])
end.select{|x| !x.nil?}

all_dates = torrents.inject(Set.new){|acc, t| acc << t.date}

all_dumps = all_dates.map{ |d|
  date_torrents = torrents.select{|t| t.date == d}
  Dump.new(date_torrents, d)
}

max_date = all_dates.max{|a,b| a <=> b}

ghtorrent = GHTorrent.new(max_date)
all_dumps.each {|x|
  ghtorrent.add_dump x
  x.torrents.each {|t|
    ghtorrent.add_collection t.name
  }
}

rhtml.run(ghtorrent.get_binding)
rhtml.result()