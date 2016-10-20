require 'rubygems'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/command'
require 'ghtorrent/retriever'
require 'ghtorrent/transacted_gh_torrent'
require 'ghtorrent/commands/full_user_retriever'

class GHTRetrieveUser < GHTorrent::Command

  include GHTorrent::Retriever
  include GHTorrent::Commands::FullUserRetriever

  def prepare_options(options)
    options.banner <<-BANNER
An efficient way to get all data for a single user

#{command_name} [options] login

    BANNER
  end

  def validate
    super
    Trollop::die "One argument is required" unless args[0] && !args[0].empty?
  end

  def ght
    @ght ||= get_mirror_class.new(settings)
    @ght
  end

  def go
    login = ARGV[0]
    retrieve_user(login)
  end

end
