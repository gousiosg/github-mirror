require 'logger'

require 'ghtorrent/settings'

module GHTorrent
  module Logging

    include GHTorrent::Settings

    def error(msg)
      log(:error, msg)
    end

    def warn(msg)
      log(:warn, msg)
    end

    def info(msg)
      log(:info, msg)
    end

    def debug(msg)
      log(:debug, msg)
    end

    # Default logger
    def loggerr
      @logger ||= proc do
        @logger_uniq ||= config(:logging_uniq)

        logger = if config(:logging_file).casecmp('stdout')
                   Logger.new(STDOUT)
                 elsif config(:logging_file).casecmp('stderr')
                   Logger.new(STDERR)
                 else
                   Logger.new(config(:logging_file))
                 end

        logger.level =
            case config(:logging_level).downcase
              when 'debug' then
                Logger::DEBUG
              when 'info' then
                Logger::INFO
              when 'warn' then
                Logger::WARN
              when 'error' then
                Logger::ERROR
              else
                Logger::INFO
            end

        logger.formatter = proc do |severity, time, progname, msg|
          if progname.nil? or progname.empty?
            progname = @logger_uniq
          end
          "#{severity}, #{time.iso8601}, #{progname} -- #{msg}\n"
        end
        logger
      end.call

      @logger
    end

    private

    def retrieve_caller
      @logprefixes ||= Hash.new

      c = caller[2]
      unless @logprefixes.key? c
        # ignore the first two chars to allow this to run on Windows with c:\...
        file_path = c[2,c.length - 2].split(/:/)[0]
        @logprefixes[c] = File.basename(file_path) + ': '
      end

      @logprefixes[c]

    end

    # Log a message at the given level.
    def log(level, msg)

      case level
        when :fatal then
          loggerr.fatal (retrieve_caller + msg)
        when :error then
          loggerr.error (retrieve_caller + msg)
        when :warn then
          loggerr.warn  (retrieve_caller + msg)
        when :info then
          loggerr.info  (retrieve_caller + msg)
        when :debug then
          loggerr.debug (retrieve_caller + msg)
        else
          loggerr.debug (retrieve_caller + msg)
      end
    end
  end
end