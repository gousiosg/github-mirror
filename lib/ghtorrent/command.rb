require 'rubygems'
require 'trollop'
require 'bunny'
require 'etc'

require 'ghtorrent/settings'
require 'version'

module GHTorrent

  # Base class for all GHTorrent command line utilities. Provides basic command
  # line argument parsing and command bootstraping support. The order of
  # initialization is the following:
  # prepare_options
  # validate
  # go
  class Command

    include GHTorrent::Settings
    include GHTorrent::Logging

    # Specify the run method for subclasses.
    class << self
      def run(args = ARGV)
        attr_accessor :args
        attr_accessor :settings
        attr_accessor :name
        attr_accessor :options

        command = new()

        command.name = self.class.name
        command.args = args

        command.process_options
        command.validate

        command.settings = YAML::load_file command.options[:config]

        unless command.options[:addr].nil?
          command.settings = command.override_config(command.settings,
                                                     :attach_ip,
                                                     command.options[:addr])
        end

        unless command.options[:token].nil?
          command.settings = command.override_config(command.settings,
                                                     :github_token,
                                                     command.options[:token])
        end

        unless command.options[:req_limit].nil?
          command.settings = command.override_config(command.settings,
                                                     :req_limit,
                                                     command.options[:req_limit])
        end

        unless command.options[:uniq].nil?
          command.settings = command.override_config(command.settings,
                                                     :logging_uniq,
                                                     command.options[:uniq])
        end


        begin
          command.go
        rescue => e
          STDERR.puts e.message
          if command.options.verbose
            STDERR.puts e.backtrace.join("\n")
          else
            STDERR.puts e.backtrace[0]
          end
          exit 1
        end
      end
    end

    # Specify and parse top-level command line options.
    def process_options
      command = self
      @options = Trollop::options(command.args) do

        command.prepare_options(self)

        banner <<-END
Standard options:
        END

        opt :config, 'config.yaml file location', :short => 'c',
            :default => 'config.yaml'
        opt :verbose, 'verbose mode', :short => 'v'
        opt :addr, 'IP address to use for performing requests', :short => 'a',
            :type => String
        opt :token, 'GitHub OAuth token',
            :type => String, :short => 't'
        opt :req_limit, 'Number or requests to leave on any provided account (in reqs/hour)',
            :type => Integer, :short => 'l'
        opt :uniq, 'Unique name for this command. Will appear in logs.',
            :type => String, :short => 'u'
      end
    end

    # Get the version of the project
    def version
      IO.read(File.join(File.dirname(__FILE__), '..', '..', 'VERSION'))
    end

    # This method should be overriden by subclasses in order to specify,
    # using trollop, the supported command line options
    def prepare_options(options)
    end

    # Examine the validity of the provided options in the context of the
    # executed command. Subclasses can also call super to also invoke the checks
    # provided by this class.
    def validate
      if options[:config].nil?
        unless (File.exist?("config.yaml"))
          Trollop::die "No config file in default location (#{Dir.pwd}). You
                        need to specify the #{:config} parameter. Read the
                        documentation on how to create a config.yaml file."
        end
      else
        Trollop::die "Cannot find file #{options[:config]}" \
          unless File.exist?(options[:config])
      end

      unless @options[:user].nil?
        if not Process.uid == 0
          Trollop::die "Option --user (-u) can only be specified by root"
        end
          begin
            Etc.getpwnam(@options[:user])
          rescue ArgumentError
            Trollop::die "No such user: #{@options[:user]}"
          end
      end
    end

    # Name of the command that is currently being executed.
    def command_name
      File.basename($0)
    end

    # The actual command code.
    def go
    end

    # Specify a handler to incoming messages from a connection to a queue.
    #
    # @param queue [String] the queue name to bind to
    # @param key [String] routing key for msgs for binding the queue to the exchange.
    # @param ack [Symbol] when should acks be send, :before or :after the block returns
    # @param block [Block]: A block accepting one argument (the message)
    def queue_client(queue, key = queue, ack = :after, block)

      stopped = false
      while not stopped
        begin
          conn = Bunny.new(:host => config(:amqp_host),
                           :port => config(:amqp_port),
                           :username => config(:amqp_username),
                           :password => config(:amqp_password))
          conn.start

          ch  = conn.create_channel
          debug "Queue setting prefetch to #{config(:amqp_prefetch)}"
          ch.prefetch(config(:amqp_prefetch))
          debug "Queue connection to #{config(:amqp_host)} succeeded"

          x = ch.topic(config(:amqp_exchange), :durable => true,
                       :auto_delete => false)
          q = ch.queue(queue, :durable => true)
          q.bind(x, :routing_key => key)

          q.subscribe(:block => true,
                      :manual_ack => true) do |delivery_info, properties, msg|

            if ack == :before
              ch.acknowledge(delivery_info.delivery_tag)
            end

            begin
              block.call(msg)
            ensure
              if ack != :before
                ch.acknowledge(delivery_info.delivery_tag)
              end
            end
          end

        rescue Bunny::TCPConnectionFailed => e
          warn "Connection to #{config(:amqp_host)} failed. Retrying in 1 sec"
          sleep(1)
        rescue Bunny::PossibleAuthenticationFailureError => e
          warn "Could not authenticate as #{conn.username}"
        rescue Bunny::NotFound, Bunny::AccessRefused, Bunny::PreconditionFailed => e
          warn "Channel error: #{e}. Retrying in 1 sec"
          sleep(1)
        rescue Interrupt => _
          stopped = true
        rescue StandardError => e
          raise e
        end
      end

      ch.close unless ch.nil?
      conn.close unless conn.nil?

    end

    def override_config(config_file, setting, new_value)
      puts "Overriding configuration #{setting}=#{config(setting)} with new value #{new_value}"
      super(config_file, setting, new_value)
    end

  end

end
# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
