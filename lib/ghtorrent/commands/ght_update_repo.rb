#!/usr/bin/env ruby

require 'ghtorrent/commands/repo_updater'

class GHTUpdateRepo < GHTorrent::Command

  include GHTorrent::Commands::RepoUpdater

  def prepare_options(options)
    options.banner <<-BANNER
Updates repo entries in MongoDB and MySQL with fresh data. Marks the project
as deleted if it cannot be accessed on GitHub.

#{command_name} owner repo

    BANNER
  end

  def validate
    super
    Optimist::die "Takes two arguments" if ARGV.size == 1
  end

  def settings
    @config
  end

  def go
    process_project(ARGV[0], ARGV[1])
  end

end
