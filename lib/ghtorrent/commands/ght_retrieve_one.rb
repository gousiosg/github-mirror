require 'rubygems'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/retriever'

class GHTRetrieveOne < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def prepare_options(options)
    options.banner <<-BANNER
Retrieve just one item

#{command_name} [options] <what> options...
  what can have the following values and arguments
    * pullreq <owner> <repo> <github_id>
    * issue <owner> <repo> <github_id>
    BANNER
  end


  def validate
    super
    Trollop::die 'One argument required' unless args[0] && !args[0].empty?
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
    @ght ||= TransactedGHTorrent.new(settings)
    @ght
  end

  def go

    ght.get_db
    case ARGV[0]
      when /pullreq/
        retrieve_pullreq(ARGV[1..-1])
      when /issue/
        retrieve_issue(ARGV[1..-1])
      else
        Trollop::die "Don't know how to retrieve #{ARGV[0]}"
    end
  end

  def retrieve_pullreq(args)
    owner = args[0]
    repo = args[1]
    pull_req_id = args[2]

    ght.ensure_pull_request(owner, repo, pull_req_id)
  end

  def retrieve_issue(args)
    owner = args[0]
    repo = args[1]
    issue_id = args[2]

    ght.ensure_issue(wner, repo, issue_id)
  end

end