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
Loads data from a MongoDB collection or a file to a queue for further processing.

#{command_name} [options] mongo_collection
#{command_name} [options] -i input_file

#{command_name} options:
    BANNER

    options.opt :earliest, 'Seconds since epoch of earliest item to load (Mongo mode only)',
                :short => 'e', :default => 0, :type => :int
    options.opt :latest, 'Seconds since epoch of latest item to load (Mongo mode only)',
                :short => 'x', :default => Time.now.to_i + (60 * 60 * 24 * 360 * 20),
                :type => :int
    options.opt :filter,
                'Filter items by regexp on item attributes: item.attr=regexp (Mongo mode only)',
                :short => 'f', :type => String, :multi => true

    options.opt :input, 'Input file', :type => String
    options.opt :number, 'Total number of items to load',
                :short => 'n', :type => :int, :default => 2**48
    options.opt :rate, 'Number of items to load per second',
                :type => :int, :default => 1000
    options.opt :route_key, 'Routing key to attached to loaded items', :type => String
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

    if options[:file_given]
      Trollop::die "File does not exist: #{options[:file]}" unless File.exists?(options[:file])
    end
  end

  def mongo_stream
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

    persister.get_underlying_connection[:events].find(what.merge(from),
                                                      :snapshot => true)
  end

  def mongo_process(e)
    unq = read_value(e, 'type')
    if unq.class != String or unq.nil? then
      raise Exception.new('Unique value can only be a String')
    end

    [e['id'], "evt.#{e['type']}"]
  end

  def file_stream
    File.open(options[:file])
  end

  def file_process(e)
    [e, '']
  end

  def go

    if options[:file_given]
      @mode = :file
      alias_method :process, :file_process
      alias_method :stream, :file_stream
    else
      @mode = :mongodb
      alias_method :process, :mongo_process
      alias_method :stream, :mongo_stream
    end

    # Num events read
    total_read = current_sec_read = 0

    conn = Bunny.new(:host => config(:amqp_host),
                     :port => config(:amqp_port),
                     :username => config(:amqp_username),
                     :password => config(:amqp_password))
    conn.start

    channel = conn.create_channel
    puts "Connection to #{config(:amqp_host)} succeeded"

    exchange = channel.topic(config(:amqp_exchange),
                             :durable => true, :auto_delete => false)
    stopped = false
    ts = Time.now.to_f
    while not stopped
      begin
        stream.each do |e|
          id, route = process(e)

          if options[:route_key_given]
            route = options[:route_key]
          end

          exchange.publish id, :persistent => false, :routing_key => route

          total_read += 1
          puts "Publish id = #{id} (#{total_read} read)" if options.verbose

          # Basic rate limiting
          if options[:rate_given]
            current_sec_read += 1
            if current_sec_read >= options[:rate]
              time_diff = Time.now.to_f - ts
              if time_diff <= 1000
                puts "Rate limit reached, sleeping for #{1000 - time_diff} ms"
                sleep(1000 - time_diff)
              end
              current_sec_read = 0
            end
          end

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
