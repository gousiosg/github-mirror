require 'logger'

module GHTorrent
  module Logging

    DEBUG_LEVEL = defined?(Logger) ? Logger::DEBUG : 0

    def warn(msg)
      log(:warn, msg)
    end

    def info(msg)
      log(:info, msg)
    end

    def debug(msg)
      log(:debug, msg)
    end

    private

    def retrieve_caller
      @logprefixes ||= Hash.new

      c = caller[2]
      unless @logprefixes.key? c
        file_path = c.split(/:/)[0]
        @logprefixes[c] = File.basename(file_path) + ': '
      end

      @logprefixes[c]

    end

    # Log a message at the given level.
    def log(level, msg)

      case level
        when :fatal then
          logger.fatal (retrieve_caller + msg)
        when :error then
          logger.error (retrieve_caller + msg)
        when :warn then
          logger.warn  (retrieve_caller + msg)
        when :info then
          logger.info  (retrieve_caller + msg)
        when :debug then
          logger.debug (retrieve_caller + msg)
        else
          logger.debug (retrieve_caller + msg)
      end
    end

    # Default logger
    def logger
      @logger ||= Logger.new(STDOUT)
    end
  end
end