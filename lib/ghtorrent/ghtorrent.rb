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

class GHTorrent

  attr_reader :num_api_calls
  attr_reader :settings
  attr_reader :log
  attr_reader :url_base

  def init(config)
    @settings = YAML::load_file config
    get_mongo
    @ts = Time.now().tv_sec()
    @num_api_calls = 0
    @log = Logger.new(STDOUT)
    @url_base = @settings['mirror']['urlbase']
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

  def followed_col
    @db.collection(@settings['mongo']['followed'])
  end

  def followers_col
    @db.collection(@settings['mongo']['followers'])
  end

  def users_col
    @db.collection(@settings['mongo']['users'])
  end

  def repos_col
    @db.collection(@settings['mongo']['repos'])
  end

  # Specific API call functions and caches

  # Get commit information.
  # This method uses the v2 API for retrieving commits
  def get_commit_v2(user, repo, sha)
    url = "http://github.com/api/v2/json/commits/show/%s/%s/%s"
    get_commit url, commits_col, 'commit.id', user, repo, sha
  end

  # Get commit information.
  # This method uses the v3 API for retrieving commits
  def get_commit_v3(user, repo, sha)
    url = @url_base + "repos/%s/%s/commits/%s"
    get_commit url, commits_col_v3, 'sha', user, repo, sha
  end

  # Get watched repositories for user
  def get_watched(user, evt)
    update_user(user, evt)
    url = @url_base + "users/%s/watched"

    prev = watched_col.find({:ght_owner => user},
                            :sort => :ght_eventid.to_s).to_a
    data = api_request(url % user)

    # Find all new watch entries that are not in the database
    new = data.reduce([]) do |acc, x|
      if prev.find{ |y|
        y[:url.to_s] == x[:url.to_s]
      } then
        acc
      else
        acc << x
      end
    end

    last = if prev.empty? then nil else prev[-1][:_id.to_s] end

    new.each do |x|
      ensure_user(x[:owner.to_s][:login.to_s], evt)
      #ensure_repo(x[:owner.to_s][:login.to_s], evt)

      # Write custom information to associate data per owning entity
      x[:ght_prev] = last
      x[:ght_owner] = user
      x[:ght_eventid] = evt[:id]
      x[:ght_ts] = evt[:created_at]
      last = watched_col.insert(x)
      @log.info "User #{user} watches #{x[:url.to_s]}"
    end
  end

  # Ensure that a user exists, or fetch its latest state from Github
  def ensure_user(user, evt)
    if users_col.find_one({:login => user}, :sort => ["_id", :desc]).nil?
      url = @url_base + "users/%s"
      data = api_request(url % user)
      data[:ght_prev] = nil
      data[:ght_eventid] = evt[:id]
      data[:ght_ts] = evt[:created_at]
      users_col.insert(data)
      @log.info "New user #{user}"
    end
  end

  # Update a user's state from Github, iff the user's state changed
  def update_user(user, evt)
    last = users_col.find_one({:login => user}, :sort => ["_id", :desc])
    url = @url_base + "users/%s"
    data = api_request(url % user)

    changed = if last.nil?
                true
              else
                data.find{|k, v| if last[k] != data[k] then true else false end}
              end

    if changed
      data[:ght_prev] = if last.nil? then nil else last[:_id] end
      data[:ght_eventid] = evt[:id]
      data[:ght_ts] = evt[:created_at]
      users_col.insert(data)
      @log.info "New instance for user #{user}"
    end
  end

  # Ensure that a repo exists, or fetch its latest state from Github
  def ensure_repo(user, repo, evt)
    if users_col.find_one({:ght_owner => user}, :sort => ["_id", :desc]).nil?
      url = @url_base + "users/%s"
      data = api_request(url % user)
      data[:ght_prev] = nil
      data[:ght_eventid] = evt[:id]
      data[:ght_ts] = evt[:created_at]
      users_col.insert(data)
      @log.info "New user #{user}"
    end
  end

  # Get the users followed by the event actor
  def get_followed(user)
    url = @url_base + "users/%s/following"
    data = api_request(url % user)
    followed_col.insert(data)
    @log.info "Followed #{user}"
  end

  # Get the users followed by the event actor
  def get_followers(user)
    url = @url_base + "users/%s/followers"
    data = api_request(url % user)
    followers_col.insert(data)
    @log.info "Followed by #{user}"
  end

  # Get current Github events
  def get_events
    api_request "https://api.github.com/events"
  end

  # Read a value whose format is "foo.bar.baz" from a hierarchical map
  # (the result of a JSON parse or a Mongo query), where a dot represents
  # one level deep in the result hierarchy.
  def read_value(from, key)
    return from if key.nil? or key == ""

    key.split(/\./).reduce({}) do |acc, x|
      unless acc.nil?
        if acc.empty?
          # Initial run
          acc = from[x]
        else
          if acc.has_key?(x)
            acc = acc[x]
          else
            # Some intermediate key does not exist
            return ""
          end
        end
      else
        # Some intermediate key returned a null value
        # This indicates a malformed entry
        return ""
      end
    end
  end

  private

  def get_commit(urltmpl, col, commit_id, user, repo, sha)
    unless sha.match(/[a-f0-9]{40}$/)
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

  def api_request(url)
    JSON.parse(api_request_raw(url))
  end

  def api_request_raw(url)
    #Rate limiting to avoid error requests
    if Time.now().tv_sec() - @ts < 60 then
      if @num_api_calls >= @settings['mirror']['reqrate'].to_i
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
    open(url).read
  end
end

class BSON::OrderedHash

  def to_h
    inject({}) do |acc, element| 
      k,v = element
      acc[k] = (if v.class == BSON::OrderedHash then v.to_h else v end)
      acc 
    end
  end

  def json
    to_h.to_json
  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
