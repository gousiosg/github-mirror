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

    # Log a message with the given level.
    def log(level, msg)
      return unless @logger
      case level
        when :fatal then
          @logger.fatal "GHTorrent [FATAL] #{msg}"
        when :error then
          @logger.error "GHTorrent [ERROR] #{msg}"
        when :warn then
          @logger.warn "GHTorrent [WARNING] #{msg}"
        when :info then
          @logger.info "GHTorrent [INFO] #{msg}"
        when :debug then
          @logger.debug "GHTorrent [DEBUG] #{msg}"
        else
          @logger.debug "GHTorrent [DEBUG] #{msg}"
      end
    end
  end
end