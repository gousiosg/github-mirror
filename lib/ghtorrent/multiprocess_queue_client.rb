# A generic class to implement a multiprocess client for clients that listen
# to the same queue for incoming messages.
#
# Client creation is driven by an input file whose format is described
# in #options.banner.
#
# MultiprocessQueueClient expects overriding classes to overload the #clazz method
# with the name of a class that respects the following protocol:
#
# @example
#   class ExampleQueueClient
#     # Constructor accepting a GHTorrent::Settings and a String object
#     # representing the client configuration and the queue to connect to
#     def initialize(config, queue); end
#
#     # Start processing using the specified GHTorrent::Command as input
#     def run(command); end
#
#     # Stop processing of queue messages
#     def stop; end
#   end
#
# MultiprocessQueueClient does not do any error handling/respawning of
# dead children. Client/Sub classes are expected to handle errors by
# themselves.
class MultiprocessQueueClient < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Logging

  def clazz
    raise('Unimplemented')
  end

  def prepare_options(options)
    options.banner <<-BANNER
Retrieve data for multiple repos in parallel. To work, it requires
a mapping file formatted as either of the follow formats:

U IP UNAME PASSWD NUM_PROCS
T IP TOKEN NUM_PROCS

{U,T}: U signifies that a username/password pair is provided, T that an OAuth
       token is specified instead
IP: address to use for outgoing requests (use 0.0.0.0 on non-multihomed hosts)
UNAME: Github user name to use for outgoing requests
PASSWD: Github password to use for outgoing requests
TOKEN: Github OAuth token
NUM_PROCS: Number of processes to spawn for this IP/UNAME combination

Values in the config.yaml file set with the -c command are overridden.

#{command_name} [options] mapping-file

    BANNER
    options.opt :queue, 'Queue to retrieve project names from',
                :short => 'q', :default => 'multiprocess-queue-client',
                :type => :string
  end

  def validate
    super
    Trollop::die 'Argument mapping-file is required' unless not args[0].nil?
  end

  def go

    configs = File.open(ARGV[0]).readlines.map do |line|
      next if line =~ /^#/
      case line.strip.split(/ /)[0]
        when 'U'
          type, ip, name, passwd, instances = line.strip.split(/ /)
        when 'T'
          type, ip, token, instances = line.strip.split(/ /)
      end

      (1..instances.to_i).map do |i|
        newcfg = self.settings.clone
        newcfg = override_config(newcfg, :attach_ip, ip)

        case type
          when 'U'
            newcfg = override_config(newcfg, :github_username, name)
            newcfg = override_config(newcfg, :github_passwd, passwd)
          when 'T'
            newcfg = override_config(newcfg, :github_token, token)
        end

        newcfg
      end
    end.flatten.select { |x| !x.nil? }

    children = configs.map do |config|
      pid = Process::fork

      if pid.nil?
        retriever = clazz.new(config, options[:queue], options)

        Signal.trap('TERM') {
          retriever.stop
        }

        retriever.run(self)
        exit
      else
        debug "Parent #{Process.pid} forked child #{pid}"
        pid
      end
    end

    debug 'Waiting for children'
    begin
      children.each do |pid|
        debug "Waiting for child #{pid}"
        Process.waitpid(pid, 0)
        debug "Child #{pid} exited"
      end
    rescue Interrupt
      debug 'Stopping'
    end
  end
end

# vim: ft=ruby: