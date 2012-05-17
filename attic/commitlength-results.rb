#!/usr/bin/env ruby
require 'ghtorrent-old'

github = Mirror.new

puts "lang added removed"
github.commitlength_col\
      .find({},:fields => %w(add del lang)).each do |x|
  puts "#{x['lang']} #{x['add']} #{x['del']}"
end
