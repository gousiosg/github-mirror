# Copyright 2012 Georgios Gousios <gousiosg@gmail.com>
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#   1. Redistributions of source code must retain the above
#      copyright notice, this list of conditions and the following
#      disclaimer.
#
#   2. Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials
#      provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'rubygems'
require 'mongo'
require 'yaml'
require 'json'
require 'net/http'
require 'logger'
require 'set'
require 'open-uri'

# Mongo preparation

# db.createCollection("commits")
# db.owners.ensureIndex({'commits.id': 1})
# db.createCollection("owners")
# db.owners.ensureIndex({pr: 1})

class GithubAnalysis

  attr_reader :num_api_calls
  attr_reader :settings
  attr_reader :log

  def initialize
    @settings = YAML::load_file "config.yaml"
    get_mongo
    @ts = Time.now().tv_sec()
    @num_api_calls = 0
    @log = Logger.new(STDOUT)
  end

  # Mongo related functions
  def get_mongo
    @db = Mongo::Connection.new(@settings['mongo']['host'],
                                @settings['mongo']['port'])\
                           .db(@settings['mongo']['db'])
    #@db.authenticate(@settings['mongo']['username'],
    #                 @settings['mongo']['password'])
    @db
  end

  def commits_col
    @db.collection(@settings['mongo']['commits'])
  end

  def commits_col_v3
    @db.collection(@settings['mongo']['commitsv3'])
  end

  def watched_col
    @db.collection(@settings['mongo']['watched'])
  end

  def events_col
    @db.collection(@settings['mongo']['events'])
  end

  # Specific API call functions and caches

  # Get commit information.
  # This method uses the v2 API for retrieving commits
  def get_commit_v2 user, repo, sha
    url = "http://github.com/api/v2/json/commits/show/%s/%s/%s"
    get_commit url, commits_col, 'commit.id', user, repo, sha
  end

  # Get commit information.
  # This method uses the v3 API for retrieving commits
  def get_commit_v3 user, repo, sha
    url = @settings['mirror']['urlbase'] + "repos/%s/%s/commits/%s"
    get_commit url, commits_col_v3, 'sha', user, repo, sha
  end

  # Get watched repositories for user
  def get_watched user
    url = @settings['mirror']['urlbase'] + "users/%s/watched"
    data = api_request(url % user)
    watched_col.insert(data)
    @log.info "Watched #{user}"
  end

  # Get current Github events
  def get_events
    api_request "https://api.github.com/events"
  end

  private

  def get_commit urltmpl, col, commit_id, user, repo, sha
    if not sha.match(/[a-f0-9]{40}$/) then
      @log.warn "Ignoring #{line}"
      return
    end

    if col.find({"#{commit_id}" => "#{sha}"}).has_next? then
      @log.info "Already got #{sha}"
    else
      result = api_request urltmpl%[user, repo, sha]
      col.insert(result)
      @log.info "Commit #{sha}"
    end
  end

  def api_request url
    JSON.parse(api_request_raw(url))
  end

  def api_request_raw url
    #Rate limiting to avoid error requests
    if Time.now().tv_sec() - @ts < 60 then
      if @num_api_calls >= @settings['mirror']['reqrate'].to_i then
        @log.debug "Sleeping for #{Time.now().tv_sec() - @ts}"
        sleep (Time.now().tv_sec() - @ts)
        @num_api_calls = 0
        @ts = Time.now().tv_sec()
      end
    else
      @log.debug "Tick, num_calls = #{@num_api_calls}, zeroing"
      @num_api_calls = 0
      @ts = Time.now().tv_sec()
    end

    @num_api_calls += 1
    @log.debug("Request: #{url} (num_calls = #{num_api_calls})")
    data = open(url).read
    #resp = Net::HTTP.get_response(URI.parse(url))
    return data
  end
end
