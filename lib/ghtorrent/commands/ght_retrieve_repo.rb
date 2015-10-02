require 'rubygems'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/command'
require 'ghtorrent/retriever'

class GHTRetrieveRepo < GHTorrent::Command

  include GHTorrent::Commands::FullRepoRetriever

  def prepare_options(options)
    options.banner <<-BANNER
An efficient way to get all data for a single repo

#{command_name} [options] owner repo

    BANNER
    supported_options
  end

  def validate
    super
    validate_options
  end

  def go
    retrieve_repo(owner, repo)
  end
end
