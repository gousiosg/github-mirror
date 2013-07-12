require 'rubygems'
require 'yaml'
require 'amqp'
require 'eventmachine'
require 'json'
require 'logger'

require 'ghtorrent/api_client'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/persister'
require 'ghtorrent/command'

class GHTMirrorEvents < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Logging
  include GHTorrent::Persister
  include GHTorrent::APIClient

  def logger
    @logger
  end

  def store_count(events)
    stored = Array.new
    new = dupl = 0
    events.each do |e|
      if @persister.find(:events, {'id' => e['id']}).empty?
        stored << e
        new += 1
        @persister.store(:events, e)
        info "Added #{e['id']}"
      else
        info "Already got #{e['id']}"
        dupl += 1
      end
    end
    return new, dupl, stored
  end

  # Retrieve events from Github, store them in the DB
  def retrieve(exchange)
    begin
      new = dupl = 0
      events = api_request "https://api.github.com/events", false
      (new, dupl, stored) = store_count events

      # This means that first page cannot contain all new events. Go
      # up to 10 pages back to find all new events not contained in first page.
      if dupl == 0
        events = paged_api_request "https://api.github.com/events"
        (new1, dupl1, stored1) = store_count events
        stored = stored | stored1
        new = new + new1
        new
      end

      stored.each do |e|
        key = "evt.%s" % e['type']
        exchange.publish e['id'], :persistent => true, :routing_key => key
      end
      return new, dupl
    rescue Exception => e
      STDERR.puts e.message
      STDERR.puts e.backtrace
    end
  end

  def go
    @persister = connect(:mongo, @settings)
    @logger = Logger.new(STDOUT)

    # Graceful exit
    Signal.trap('INT') {
      info "Received SIGINT, exiting"
      AMQP.stop { EM.stop }
    }
    Signal.trap('TERM') {
      info "Received SIGTERM, exiting"
      AMQP.stop { EM.stop }
    }

    # The event loop
    AMQP.start(:host => config(:amqp_host),
               :port => config(:amqp_port),
               :username => config(:amqp_username),
               :password => config(:amqp_password)) do |connection|

      # Statistics used to recalibrate event delays
      dupl_msgs = new_msgs = 1

      debug "connected to rabbit"

      channel = AMQP::Channel.new(connection)
      exchange = channel.topic(config(:amqp_exchange), :durable => true,
                               :auto_delete => false)

      # Retrieve events
      EventMachine.add_periodic_timer(5) do
        (new, dupl) = retrieve exchange
        dupl_msgs += dupl
        new_msgs += new
      end

      # Adjust event retrieval delay time to reduce load to Github
      EventMachine.add_periodic_timer(12) do
        ratio = (dupl_msgs.to_f / (dupl_msgs + new_msgs).to_f)

        info("Stats: #{new_msgs} new, #{dupl_msgs} duplicate, ratio: #{ratio}")

        # Reset counters for new loop
        dupl_msgs = new_msgs = 0
      end
    end
  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
