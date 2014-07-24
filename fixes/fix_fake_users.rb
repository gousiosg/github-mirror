#!/usr/bin/env ruby

require 'ghtorrent'

class FixFakeUsers < MultiprocessQueueClient
  def clazz
    FixFakeUser
  end
end

class FixFakeUser

  include GHTorrent::Settings
  include GHTorrent::APIClient

  def initialize(config, queue)
    @config = config
    @queue = queue
  end

  def logger
    @ght.logger
  end

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def ext_uniq
    @ext_uniq ||= config(:uniq_id)
    @ext_uniq
  end

  def settings
    @config
  end

  def run(command)
    processor = Proc.new do |login|
      @ght ||= GHTorrent::Mirror.new(settings)
      @ght.get_db

      exists = !api_request("https://api.github.com/users/#{login}").empty?
      @ght.get_db[:users].where(:login => login).update(:fake => exists)

      puts "User: #{login}, exists: #{exists}"
    end

    command.queue_client(@queue, :after, processor)
  end
end

FixFakeUsers.run
