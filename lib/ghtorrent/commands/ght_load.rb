require 'rubygems'
require 'mongo'
require 'amqp'
require 'set'
require 'eventmachine'
require 'pp'
require "amqp/extensions/rabbitmq"

require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/persister'
require 'ghtorrent/command'
require 'ghtorrent/bson_orderedhash'

class GHTLoad < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Persister

  def col_info()
    {
        :commits => {
            :name => "commits",
            :payload => "commit.id",
            :unq => "commit.id",
            :col => persister.get_underlying_connection.collection(:commits.to_s),
            :routekey => "commit.%s"
        },
        :events => {
            :name => "events",
            :payload => "",
            :unq => "type",
            :col => persister.get_underlying_connection.collection(:events.to_s),
            :routekey => "evt.%s"
        }
    }
  end

  def persister
    @persister ||= connect(:mongo, @settings)
    @persister
  end

  def prepare_options(options)
    options.banner <<-BANNER
Loads object ids from a collection to a queue for further processing.

#{command_name} [options] collection

#{command_name} options:
    BANNER

    options.opt :earliest, 'Seconds since epoch of earliest item to load',
                :short => 'e', :default => 0, :type => :int
    options.opt :number, 'Number of items to load (-1 means all)',
                :short => 'n', :type => :int, :default => -1
    options.opt :filter,
                'Filter items by regexp on item attributes: item.attr=regexp',
                :short => 'f', :type => String, :multi => true
  end

  def validate
    super
    Trollop::die "no collection specified" unless args[0] && !args[0].empty?
    filter = options[:filter]
    case
      when filter.is_a?(Array)
        options[:filter].each { |x|
          Trollop::die "not a valid filter #{x}" unless is_filter_valid?(x)
        }
      when filter == []
        # Noop
      else
        Trollop::die "A filter can only be a string"
    end
  end

  def go
    # Message tags await publisher ack
    awaiting_ack = SortedSet.new

    # Num events read
    num_read = 0

    collection = case args[0]
                   when "events"
                     :events
                   when "commits"
                     :commits
                 end

    puts "Loading from collection #{collection}"
    puts "Loading items after #{Time.at(options[:earliest])}" if options[:verbose]
    puts "Loading #{options[:number]} items" if options[:verbose] && options[:number] != -1

    what = case
             when options[:filter].is_a?(Array)
               options[:filter].reduce({}) { |acc,x|
                 (k,r) = x.split(/=/)
                 acc[k] = Regexp.new(r)
                 acc
               }
             when filter == []
               {}
           end

    from = {'_id' => {'$gte' => BSON::ObjectId.from_time(Time.at(options[:earliest]))}}

    (puts "Mongo filter:"; pp what.merge(from)) if options[:verbose]

    AMQP.start(:host => config(:amqp_host),
               :port => config(:amqp_port),
               :username => config(:amqp_username),
               :password => config(:amqp_password)) do |connection|

      channel = AMQP::Channel.new(connection)
      exchange = channel.topic(config(:amqp_exchange),
                               :durable => true, :auto_delete => false)

      # What to do when the user hits Ctrl+c
      show_stopper = Proc.new {
        connection.close { EventMachine.stop }
      }

      # Read next 100000 items and queue them
      read_and_publish = Proc.new {

        to_read = if options.number == -1
                    100000
                  else
                    if options.number - num_read - 1 <= 0
                      -1
                    else
                      options.number - num_read - 1
                    end
                  end

        read = 0
        col_info[collection][:col].find(what.merge(from),
                                        :skip => num_read,
                                        :limit => to_read).each do |e|

          payload = read_value(e, col_info[collection][:payload])
          payload = if payload.class == BSON::OrderedHash
                      payload.delete "_id" # Inserted by MongoDB on event insert
                      payload.to_json
                    end
          read += 1
          unq = read_value(e, col_info[collection][:unq])
          if unq.class != String or unq.nil? then
            throw Exception.new("Unique value can only be a String")
          end

          key = col_info[collection][:routekey] % unq

          exchange.publish payload, :persistent => true, :routing_key => key

          num_read += 1
          puts("Publish id = #{payload[unq]} (#{num_read} total)") if options.verbose
          awaiting_ack << num_read
        end

        # Nothing new in the DB and no msgs waiting ack
        if (read == 0 and awaiting_ack.size == 0) or to_read == -1
          puts("Finished reading, exiting")
          show_stopper.call
        end
      }

      # Remove acknowledged or failed msg tags from the queue
      # Trigger more messages to be read when ack msg queue size drops to zero
      publisher_event = Proc.new { |ack|
        if ack.multiple then
          awaiting_ack.delete_if { |x| x <= ack.delivery_tag }
        else
          awaiting_ack.delete ack.delivery_tag
        end

        if awaiting_ack.size == 0
          puts("ACKS.size= #{awaiting_ack.size}") if options.verbose
          EventMachine.next_tick do
            read_and_publish.call
          end
        end
      }

      # Await publisher confirms
      channel.confirm_select

      # Callback when confirms have arrived
      channel.on_ack do |ack|
        puts "ACK: tag=#{ack.delivery_tag}, mul=#{ack.multiple}" if options.verbose
        publisher_event.call(ack)
      end

      # Callback when confirms failed.
      channel.on_nack do |nack|
        puts "NACK: tag=#{nack.delivery_tag}, mul=#{nack.multiple}" if options.verbose
        publisher_event.call(nack)
      end

      # Signal handlers
      Signal.trap('INT', show_stopper)
      Signal.trap('TERM', show_stopper)

      # Trigger start processing
      EventMachine.add_timer(0.1) do
        read_and_publish.call
      end
    end
  end

  private

  def is_filter_valid?(filter)
    (k, r) = filter.split(/=/)
    return false if r.nil?
    begin
      Regexp.new(r)
      true
    rescue
      false
    end
  end
end

#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
