#!/usr/bin/env ruby
require 'ghtorrent'

github = GHTorrent.new

puts "lang added removed"
github.commitlength_col\
      .find({},:fields => ['add', 'del', 'lang']).each do |x|
  puts "#{x['lang']} #{x['add']} #{x['del']}"
end
