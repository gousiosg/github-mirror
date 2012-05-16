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

    # Log a message at the given level.
    def log(level, msg)
      return unless @logger
      case level
        when :fatal then
          @logger.fatal msg
        when :error then
          @logger.error msg
        when :warn then
          @logger.warn msg
        when :info then
          @logger.info msg
        when :debug then
          @logger.debug msg
        else
          @logger.debug msg
      end
    end
  end
end