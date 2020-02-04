#!/usr/bin/env ruby

if ARGV.size == 0
  STDERR.puts "usage: csvify.rb file > output"
  exit 1
end

may_be_eol = false
ARGF.each_char do |c|
  case c
    when '\\'
      if may_be_eol
        STDOUT.write '\\\\'
        may_be_eol = false
      else
        may_be_eol = true
      end
    when "\n"
      if may_be_eol
        STDOUT.write ' '
      else
        STDOUT.write c
      end
      may_be_eol = false
    when "\r"
      STDOUT.write ' '
    else
      if may_be_eol
        STDOUT.write '\\'
      end
      STDOUT.write c
      may_be_eol = false
  end
end
