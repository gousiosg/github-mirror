#!/usr/bin/env ruby

require 'uri'
require 'ghtorrent'

class GHTFixCommitComment < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister
  include GHTorrent::APIClient

  def prepare_options(options)
    options.banner <<-BANNER
Fixes several issues with commit comments, including user field being
overriden when entry is written in MongoDB
#{command_name} [API url for comment]

    BANNER
  end

  def validate
    super
    Trollop::die 'Missing required argument URL' if ARGV.size == 0
    uri = URI(ARGV[0])
    Trollop::die "Argument #{ARGV[0]} not a HTTPS URL" if uri.scheme != 'https'
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

  def ght
    @ght ||= GHTorrent::Mirror.new(settings)
    @ght
  end

  def db
    @db ||= ght.get_db
    @db
  end

  def go
    url = ARGV[0].split(/\//)

    owner = url[4]
    repo  = url[5]
    id    = url[7].to_i

    comment = persister.find(:commit_comments, {'id' => id}).first
    sha = comment['commit_id']

    persister.del(:commit_comments, {'id' => id})
    db[:commit_comments].where({:comment_id => id}).delete
    ght.ensure_commit_comment(owner, repo, sha, id)
  end
end

GHTFixCommitComment.run
