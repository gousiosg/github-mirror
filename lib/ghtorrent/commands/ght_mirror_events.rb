require 'yaml'
require 'json'
require 'logger'
require 'bunny'

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
  include GHTorrent::Logging

  def prepare_options(options)
    options.banner <<-BANNER
Retrieves events from the GitHup API event timeline and post them to the
appropriate queue. By default, events are posted to a queue which is
named after the event type.

If the -p option is provided, only project names for the changed projects
are submitted to the queue. Selected events, specified by the -e option
are also queued, to ensure no additional information is gone missing.

#{command_name} [options]
    BANNER
    options.opt :projects, 'Only queue project names',
                :short => 'p', :default => false
    options.opt :events_requeue, 'Events to requeue', :short => 'q',
                :default => 'MemberEvent,FollowEvent', :type => String
  end

  def persister
    @persister ||= connect(:mongo, @settings)
    @persister
  end

  def store_count(events)
    stored = Array.new
    new = dupl = 0
    return new, dupl, stored if events.nil?

    events.each do |e|
      if persister.find(:events, {'id' => e['id']}).empty?
        stored << e
        new += 1
        persister.store(:events, e)
        info "Added #{e['id']}"
      else
        info "Already got #{e['id']}"
        dupl += 1
      end
    end
    return new, dupl, stored
  end

  # Retrieve events from Github, store them in the DB and queue them
  def retrieve(exchange, event_source = '')
    begin
      event_source = event_source.empty? ? "events" :  "repos/#{event_source}/events"
      events_url = "https://api.github.com/#{event_source}?per_page=100"
      new = dupl = 0
      events = api_request events_url
      (new, dupl, stored) = store_count events

      # This means that the first page does not contain all new events. Do
      # a paged request and get everything on the queue
      if dupl == 0
        events = paged_api_request events_url
        (new1, dupl1, stored1) = store_count events
        stored = stored | stored1
        new = new + new1
      end

      stored.each do |e|
        repo = e['repo']['name'].gsub('/',' ')
        key = "evt.#{e['type']}"
        if @options[:projects_given]
          exchange.publish repo, :persistent => true, :routing_key => GHTorrent::ROUTEKEY_PROJECTS
          debug "Published update to project #{repo}"
          if @events_requeue.include? e['type']
            exchange.publish e['id'], :persistent => true, :routing_key => key
          end
        else
          exchange.publish e['id'], :persistent => true, :routing_key => key
        end
      end

      return new, dupl
    rescue StandardError => e
      STDERR.puts e.message
      STDERR.puts e.backtrace
    end
  end

  def watch_webhooks(exchange)
    channel = exchange.channel
    queue = channel.queue("Events", {:durable => true})\
                          .bind(exchange, :routing_key => "evt.Event")
    info "Binding Events handler to routing key evt.Event"
    queue.subscribe(:manual_ack => true) do |headers, properties, msg|
      start = Time.now
      begin
        retrieve(exchange, msg)
        channel.acknowledge(headers.delivery_tag, false)
        info "Success dispatching event. Repo: #{msg}, Time: #{Time.now.to_ms - start.to_ms} ms"
      rescue StandardError => e
        # Give a message a chance to be reprocessed
        if headers.redelivered?
          warn "Error dispatching event. Repo: #{msg}, Time: #{Time.now.to_ms - start.to_ms} ms"
          channel.reject(headers.delivery_tag, false)
        else
          channel.reject(headers.delivery_tag, true)
        end

        STDERR.puts e
        STDERR.puts e.backtrace.join("\n")
      end
    end

    stopped = false
    while not stopped
      begin
        sleep(1)
      rescue Interrupt => _
        debug 'Exit requested'
        stopped = true
      end
    end
  end

  def watch_github_events(exchange)
    dupl_msgs = new_msgs = loops = 0
    stopped = false
    while not stopped
      begin
        (new, dupl) = retrieve exchange
        dupl_msgs += dupl
        new_msgs += new
        loops += 1
        sleep(5)

        if loops >= 12 # One minute
          ratio = (dupl_msgs.to_f / (dupl_msgs + new_msgs).to_f)
          info("Stats: #{new_msgs} new, #{dupl_msgs} duplicate, ratio: #{ratio}")
          dupl_msgs = new_msgs = loops = 0
        end
      rescue Interrupt
        stopped = true
      rescue StandardError => e
        @logger.error e
      end
    end
  end

  def go

    @events_requeue = @options[:events_requeue].split(/,/)
    conn = Bunny.new(:host => config(:amqp_host),
                     :port => config(:amqp_port),
                     :username => config(:amqp_username),
                     :password => config(:amqp_password))
    conn.start

    channel  = conn.create_channel
    debug "Connection to #{config(:amqp_host)} succeded"

    exchange = channel.topic(config(:amqp_exchange), :durable => true,
                 :auto_delete => false)

    if (config(:mirror_mode) == 'webhooks')
      watch_webhooks exchange
    else
      watch_github_events exchange
    end
  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
