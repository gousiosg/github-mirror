require 'rubygems'
require 'mongo'
require 'amqp'
require 'eventmachine'
require 'pp'

require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/persister'
require 'ghtorrent/command'
require 'ghtorrent/bson_orderedhash'

class GHTLoad < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Persister

  def persister
    @persister ||= connect(:mongo, settings)
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
    options.opt :latest, 'Seconds since epoch of latest item to load',
                :short => 'l', :default => Time.now.to_i + (60 * 60 * 24 * 360 * 20),
                :type => :int
    options.opt :number, 'Total number of items to load',
                :short => 'n', :type => :int, :default => 2**48
    options.opt :batch, 'Number of items to process in a batch',
                :short => 'b', :type => :int, :default => 10000
    options.opt :filter,
                'Filter items by regexp on item attributes: item.attr=regexp',
                :short => 'f', :type => String, :multi => true
  end

  def validate
    super
    filter = options[:filter]
    case
      when filter.is_a?(Array)
        options[:filter].each { |x|
          Trollop::die "not a valid filter #{x}" unless is_filter_valid?(x)
        }
      when filter == []
        # Noop
      else
        Trollop::die 'A filter can only be a string'
    end
  end

  def go
    # Num events read
    total_read = 0

    puts "Loading items after #{Time.at(options[:earliest])}" if options[:verbose]
    puts "Loading items before #{Time.at(options[:latest])}" if options[:verbose]
    puts "Loading #{options[:batch]} items per batch" if options[:batch]
    puts "Loading #{options[:number]} items" if options[:verbose]

    if options[:batch] >= options[:number]
      puts "Batch > number of items, setting batch to #{options[:number]}"
      options[:batch] = options[:number]
    end

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

    from = {'_id' => {
        '$gte' => BSON::ObjectId.from_time(Time.at(options[:earliest])),
        '$lte' => BSON::ObjectId.from_time(Time.at(options[:latest]))}
    }

    (puts 'Mongo filter:'; pp what.merge(from)) if options[:verbose]

    AMQP.start(:host => config(:amqp_host),
               :port => config(:amqp_port),
               :username => config(:amqp_username),
               :password => config(:amqp_password)) do |connection|

      channel = AMQP::Channel.new(connection)
      exchange = channel.topic(config(:amqp_exchange),
                               :durable => true, :auto_delete => false)

      # What to do when the user hits Ctrl+c
      show_stopper = Proc.new {
        puts('Closing connection')
        connection.close { EventMachine.stop }
      }

      # Read next options[:batch] items and queue them
      read_and_publish = Proc.new {
        num_read = 0
        persister.get_underlying_connection[:events].find(what.merge(from),
                                        :snapshot => true,
                                        :skip => total_read,
                                        :limit => options[:batch]).each do |e|
          unq = read_value(e, 'type')
          if unq.class != String or unq.nil? then
            throw Exception.new('Unique value can only be a String')
          end

          exchange.publish e['id'], :persistent => false,
                           :routing_key => "evt.#{e['type']}"

          num_read += 1
          total_read += 1
          puts "Publish id = #{e['id']} (#{num_read} read, #{total_read} total)" if options.verbose
        end

        if total_read >= options[:number] or num_read == 0
          puts 'Finished reading, exiting'
          show_stopper.call
        else
          # Schedule new event processing cycle
          EventMachine.next_tick do
            read_and_publish.call
          end
        end
      }

      # Signal handlers
      Signal.trap('INT', show_stopper)
      Signal.trap('TERM', show_stopper)

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
