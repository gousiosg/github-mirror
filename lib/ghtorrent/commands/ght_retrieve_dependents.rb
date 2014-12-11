require 'rubygems'
require 'json'
require 'pp'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/command'

class GHTRetrieveDependents < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Logging
  include GHTorrent::Persister

  def prepare_options(options)
    options.banner <<-BANNER
Recursively retrieve all dependent entities for a specific entity
#{command_name} [options] entity entity-id

#{command_name} entity is one of (in parenthesis the entity-id fields):
commit        (owner repo sha)
issue         (owner repo issue_id)
pull_request  (owner repo pullreq_id)
#{command_name}
    BANNER

  end

  REQ_ARGS = {
      :commit => 3,
      :issue => 3,
      :pull_request => 3
  }

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def ghtorrent
    @gh ||= GHTorrent::Mirror.new(@settings)
    @gh
  end

  def db
    @db ||= ghtorrent.get_db
    @db
  end

  def go
    db
    type = case ARGV[0]
             when 'commit'
               :commit
             when 'issue'
               :issue
             when 'pull_request'
               :pull_request
             else
               Trollop::die("Don't know how to handle #{ARGV[0]}")
           end
    unless ARGV.size - 1 == REQ_ARGS[type]
      Trollop::die("#{ARGV[0]} requires #{REQ_ARGS[type]} arguments")
    end

    case type
      when :commit
        ghtorrent.ensure_commit(ARGV[2], ARGV[3], ARGV[1], true)
      when :issue
        ghtorrent.ensure_issue(ARGV[1], ARGV[2], ARGV[3], true, true, true)
      when :pull_request
        ghtorrent.ensure_pull_request(ARGV[1], ARGV[2], ARGV[3], true, true, true)
    end

  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
