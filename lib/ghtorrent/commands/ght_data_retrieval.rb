require 'rubygems'
require 'bunny'
require 'json'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'

class GHTDataRetrieval < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Logging
  include GHTorrent::Persister
  include GHTorrent::EventProcessing

  def handlers
    %w(PushEvent WatchEvent FollowEvent MemberEvent CreateEvent
        CommitCommentEvent PullRequestEvent ForkEvent
        PullRequestReviewCommentEvent IssuesEvent IssueCommentEvent)
    #%w(ForkEvent)
  end

  def prepare_options(options)
    options.banner <<-BANNER
Retrieves events from queues and processes them through GHTorrent.
If event_id is provided, only this event is processed.
#{command_name} [event_id]
    BANNER

  end

  def validate
    super
  end

  def ght
    @gh ||= get_mirror_class.new(settings)
    @gh
  end

  def logger
    ght.logger
  end

  def persister
    ght.persister
  end

  def retrieve_event(evt_id)
    event = persister.find(:events, {'id' => evt_id}).first
    event.delete '_id'
    data = JSON.parse(event.to_json)
    debug "Processing event: #{data['type']}-#{data['id']}"
    data
  end

  def go

    unless ARGV[0].nil?
      event = retrieve_event(ARGV[0])

      if event.nil?
        warn "No event with id: #{ARGV[0]}"
      else
        start = Time.now
        send(event['type'], event)
        info "Success processing event. Type: #{event['type']}, ID: #{event['id']}, Time: #{Time.now.to_ms - start.to_ms} ms"
      end
      return
    end

    conn = Bunny.new(:host => config(:amqp_host),
                     :port => config(:amqp_port),
                     :username => config(:amqp_username),
                     :password => config(:amqp_password))
    conn.start

    channel = conn.create_channel
    debug "Setting prefetch to #{config(:amqp_prefetch)}"
    channel.prefetch(config(:amqp_prefetch))
    debug "Connection to #{config(:amqp_host)} succeded"

    exchange = channel.topic(config(:amqp_exchange), :durable => true,
                             :auto_delete => false)

    handlers.each do |h|
      queue = channel.queue("#{h}s", {:durable => true})\
                         .bind(exchange, :routing_key => "evt.#{h}")

      info "Binding handler #{h} to routing key evt.#{h}"

      queue.subscribe(:manual_ack => true) do |headers, properties, msg|
        start = Time.now
        begin
          data = retrieve_event(msg)
          send(h, data)

          channel.acknowledge(headers.delivery_tag, false)
          info "Success processing event. Type: #{data['type']}, ID: #{data['id']}, Time: #{Time.now.to_ms - start.to_ms} ms"
        rescue StandardError => e
          # Give a message a chance to be reprocessed
          if headers.redelivered?
            warn "Error processing event. Type: #{data['type']}, ID: #{data['id']}, Time: #{Time.now.to_ms - start.to_ms} ms"
            channel.reject(headers.delivery_tag, false)
          else
            channel.reject(headers.delivery_tag, true)
          end

          STDERR.puts e
          STDERR.puts e.backtrace.join("\n")
        end
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

    debug 'Closing AMQP connection'
    channel.close unless channel.nil?
    conn.close unless conn.nil?

  end

end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
