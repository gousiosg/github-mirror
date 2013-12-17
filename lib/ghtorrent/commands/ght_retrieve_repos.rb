require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/retriever'

class GHTRetrieveRepos < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Logging

  def logger
    @logger ||= Logger.new(STDOUT)
    @logger
  end

  def prepare_options(options)
    options.banner <<-BANNER
Retrieve data for multiple repos in parallel. To work, it requires
a mapping file formatted as follows:

IP UNAME PASSWD NUM_PROCS where

IP = address to use for outgoing requests (use 0.0.0.0 on non-multihomed hosts)
UNAME = Github user name to use for outgoing requests
PASSWD = Github password to use for outgoing requests
NUM_PROCS = Number of processes to spawn for this IP/UNAME combination

Values in the config.yaml file set with the -c command are overriden.

#{command_name} [options] mapping-file

    BANNER
    options.opt :queue, 'Queue to retrieve project names from',
                :short => 'q', :default => 'retrieve-repo', :type => :string

  end

  def validate
    super
    Trollop::die 'Argument mapping-file is required' unless not args[0].nil?
  end

  def go

    configs = File.open(ARGV[0]).readlines.map do |line|
      next if line =~ /^#/
      ip,name,passwd,instances = line.strip.split(/ /)
      (1..instances.to_i).map do |i|
        newcfg = self.settings.clone
        newcfg = override_config(newcfg, :attach_ip, ip)
        newcfg = override_config(newcfg, :github_username, name)
        newcfg = override_config(newcfg, :github_passwd, passwd)
        newcfg = override_config(newcfg, :mirror_history_pages_back, 1000)
        newcfg = override_config(newcfg, :mirror_commit_pages_new_repo, 1000)
        newcfg
      end
    end.flatten.select{|x| !x.nil?}

    children = configs.map do |config|
      pid = Process::fork

      if pid.nil?
        retriever = GHTRepoRetriever.new(config, options[:queue])

        Signal.trap('TERM') {
          retriever.stop
        }

        retriever.run
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

class GHTRepoRetriever

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def initialize(config, queue)
    @config = config
    @queue = queue
  end

  def logger
    ght.logger
  end

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def ext_uniq
    @ext_uniq ||= config(:uniq_id)
    @ext_uniq
  end

  def ght
    @ght ||= TransactedGhtorrent.new(@config)
    @ght
  end

  def settings
    @config
  end

  def run
    AMQP.start(:host => config(:amqp_host),
               :port => config(:amqp_port),
               :username => config(:amqp_username),
               :password => config(:amqp_password)) do |connection|

      connection.on_tcp_connection_loss do |conn, settings|
        warn 'AMQP: Network failure. Trying to reconnect...'
        conn.reconnect(false, 2)
      end

      channel = AMQP::Channel.new(connection)
      channel.auto_recovery = true
      channel.prefetch(1)

      channel.on_error do |ch, channel_close|
        warn 'AMQP: Channel closed. Should reconnect by itself'
        raise channel_close.reply_text
      end

      exchange = channel.topic(config(:amqp_exchange), :durable => true,
                               :auto_delete => false)

      queue = channel.queue(@queue, {:durable => true}).bind(exchange)

      queue.subscribe(:ack => true) do |headers, msg|
        owner,repo = msg.split(/ /)
        user_entry = ght.transaction { ght.ensure_user(owner, false, false) }

        if user_entry.nil?
          warn("Cannot find user #{owner}")
          headers.ack
          next
        end

        repo_entry = ght.transaction { ght.ensure_repo(owner, repo) }

        if repo_entry.nil?
          warn("Cannot find repository #{owner}/#{repo}")
          headers.ack
          next
        end
  
        debug("Retrieving repo #{owner}/#{repo}")
        def send_message(function, user, repo)
          ght.send(function, user, repo, refresh = false)
        end

        functions = %w(ensure_commits ensure_forks ensure_pull_requests
          ensure_issues ensure_project_members ensure_watchers ensure_labels)

        functions.each do |x|

          begin
            send_message(x, owner, repo)
          rescue Interrupt
            stop
          rescue Exception
            warn("Error processing #{x} for #{owner}/#{repo}")
            next
          end

          if @stop
            break
          end
        end

        headers.ack
        debug("Finished processing #{owner}/#{repo}")
        if @stop
          connection.disconnect{AMQP.stop { EM.stop }}
        end
      end
    end
  end

  def stop
    warn('Stop flag set, waiting for operations to finish')
    @stop = true
  end
end

