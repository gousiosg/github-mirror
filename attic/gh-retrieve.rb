#!/usr/bin/env ruby
#

require 'ghtorrent-old'
require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'openssl'
require 'amqp'
require 'yaml'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

github = GHTorrent.new

# Get the github timeline from the RSS feed. Used to work
def get_timeline_rss
  doc = open("https://github.com/timeline.") { |f| Hpricot(f) }

  entries = doc.search("//content[@type='html']")\
                      .map { |x| x.inner_html.gsub(/&lt;/, '<')\
                      .gsub(/&gt;/, '>').gsub(/&quot;/, '\'')\
                      .gsub(/\n/, '') }.map { |x| Hpricot(x) }

  commit_hashes = entries.map { |x| x.search("//a").collect { |x| x.attributes['href'] unless x.attributes['href'].nil? } }\
                         .flatten.collect { |x| x if x =~ /commit/ }\
                         .compact\
                         .map { |x| [$1, $2, $3] if x =~/\/(.*)\/(.*)\/commit\/(.*)/ }\
                         .compact

end

# Get the github timeline from HTML
def get_timeline_html
  doc = open("https://github.com/timeline").read
  doc.split(/\n/) \
     .grep(/^\s+<code>/) \
     .map{|x| x.strip.gsub(/.*href=\"(.*)\".*/,'\1')} \
     .map{|x| x.split(/\//)} \
     .map{|x| [x[1], x[2], x[4]] if not x[4].nil?}
end

Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

mirror_method =
    if github.settings['mirror']['method'] == "rss" then
      "get_timeline_rss"
    else
      "get_timeline_html"
    end

AMQP.start(:host => github.settings['amqp']['host'],
           :username => github.settings['amqp']['username'],
           :password => github.settings['amqp']['password']) do |connection|

  puts "connected to rabbit"

  channel = AMQP::Channel.new(connection)
  exchange = channel.fanout("#{github.settings['amqp']['exchange-commits']}",
                            :durable => true, :auto_delete => false)

  EventMachine.add_periodic_timer(github.settings['amqp']['pollevery']) do
    begin
      commits = send(mirror_method)

      commits.each do |x|
        puts "Adding #{x[2]}"
        msg = "#{x[0]} #{x[1]} #{x[2]}"
        exchange.publish(msg, :persistent => true,
                         :routing_key => "commits.#{x[2]}")
      end
    rescue Exception => e
      puts e
    end
  end
end

