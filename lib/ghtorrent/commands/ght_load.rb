require 'rubygems'
require 'mongo'
require 'pp'
require 'bunny'

require 'ghtorrent/settings'
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
                :short => 'x', :default => Time.now.to_i + (60 * 60 * 24 * 360 * 20),
                :type => :int
    options.opt :number, 'Total number of items to load',
                :short => 'n', :type => :int, :default => 2**48
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

    puts "Loading events after #{Time.at(options[:earliest])}" if options[:verbose]
    puts "Loading events before #{Time.at(options[:latest])}" if options[:verbose]
    puts "Loading #{options[:number]} items" if options[:verbose]

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

    conn = Bunny.new(:host => config(:amqp_host),
                     :port => config(:amqp_port),
                     :username => config(:amqp_username),
                     :password => config(:amqp_password))
    conn.start

    channel = conn.create_channel
    puts "Connection to #{config(:amqp_host)} succeded"

    exchange = channel.topic(config(:amqp_exchange),
                             :durable => true, :auto_delete => false)

    stopped = false
    while not stopped
      begin
        persister.get_underlying_connection[:events].find(what.merge(from),
                                                          :snapshot => true).each do |e|
          unq = read_value(e, 'type')
          if unq.class != String or unq.nil? then
            raise Exception.new('Unique value can only be a String')
          end

          exchange.publish e['id'], :persistent => false,
                           :routing_key => "evt.#{e['type']}"

          total_read += 1
          puts "Publish id = #{e['id']} #{e['created_at']} (#{total_read} read)" if options.verbose

          if total_read >= options[:number]
            puts 'Finished reading, exiting'
            return 
          end
        end
        stopped = true
      rescue Interrupt
        puts 'Interrupted'
        stopped = true
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
