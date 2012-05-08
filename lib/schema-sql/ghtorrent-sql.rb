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
require 'yaml'
require 'json'
require 'net/http'
require 'logger'
require 'set'
require 'open-uri'
require 'pp'
require 'sequel'

require 'schema-sql/schema'

class GHTorrentSQL

  attr_reader :num_api_calls
  attr_reader :settings
  attr_reader :log
  attr_reader :url_base

  def init(config)
    @settings = YAML::load_file config
    get_db
    @ts = Time.now().tv_sec()
    @num_api_calls = 0
    @log = Logger.new(STDOUT)
    @url_base = @settings['mirror']['urlbase']
  end

  # db related functions
  def get_db

    @db = Sequel.connect('sqlite://github.db')
    if @db.tables.empty?
      puts("Database empty, creating schema")
      create_schema(@db)
    end
    @db
  end

  # Specific API call functions and caches

  # Get commit information.
  def get_commit(user, repo, sha)

    unless sha.match(/[a-f0-9]{40}$/)
      @log.error "Ignoring commit #{sha}"
      return
    end

    commits = @db[:commit]

    ensure_user(user)
    ensure_repo(user, repo)

    if commits.filter(:sha => sha).empty?
      url = @url_base + "repos/#{user}/#{repo}/commits/#{sha}"
      c = api_request(url)

      pp c

      ensure_user(c['commit']['author']['email'])
      ensure_user(c['commit']['committer']['email'])

      commits.insert(:sha => sha,
                     :message => c['message'],
                     :author => @db[:user].filter(:login => c['commit']['author']['email']).first[:id],
                     :committer => @db[:user].filter(:login => c['commit']['committer']['email']).first[:id]
      )

      @log.info "New commit #{sha}"
    else
      @log.debug "Commit #{sha} exists"
    end
  end

  # Ensure that a user exists, or fetch its latest state from Github
  def ensure_user(user)

    if user.match(/@/)
      ensure_user_byemail(user)
    else
      ensure_user_byuname(user)
    end
  end

  def ensure_user_byuname(user)
    users = @db[:user]
    if users.filter(:login => user).empty?
      url = @url_base + "users/#{user}"
      u = api_request(url)

      users.insert(:login => u['login'],
                   :name => u['name'],
                   :company => u['company'],
                   :email => u['email'],
                   :hireable => boolean(u['hirable']),
                   :bio => u['bio'],
                   :created_at => date(u['created_at']))

      @log.info "New user #{user}"
    else
      @log.debug "User #{user} exists"
    end
  end

  # We cannot yet retrieve users by email from Github. Just go over the
  # database and try to find the user by email, if stored.
  def ensure_user_byemail(user)

    usr = @db[:user].first(:email => user)

    if usr.nil?
      @log.warn "Cannot find user #{user}"
    end

    usr
  end

  # Ensure that a repo exists, or fetch its latest state from Github
  def ensure_repo(user, repo)

    ensure_user(user)
    repos = @db[:project]

    if repos.filter(:name => repo).empty?
      url = @url_base + "repos/#{user}/#{repo}"
      r = api_request(url)

      repos.insert(:url => r['url'],
                   :owner => @db[:user].filter(:login => user).first[:id],
                   :name => r['name'],
                   :description => r['description'],
                   :language => r['language'],
                   :created_at => date(r['created_at']))

      @log.info "New repo #{repo}"
    else
      @log.debug "Repo #{repo} exists"
    end
  end

  def boolean(arg)
    case arg
      when 'true'
        1
      when 'false'
        0
      when nil
        0
    end
  end

  # Dates returned by Github are formatted as: yyyy-mm-ddThh:mm:ssZ
  def date(arg)
    Time.parse(arg).to_i
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

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
