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
# AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
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

require 'mongo'

module GHTorrent

  # A persistence adapter that saves data into a configurable MongoDB database.
  class MongoPersister < GHTorrent::BaseAdapter

    include GHTorrent::Settings
    include GHTorrent::Logging

    # Supported configuration options.
    LOCALCONFIG = {
        :mongo_host => "mongo.host",
        :mongo_port => "mongo.port",
        :mongo_db => "mongo.db",
        :mongo_username => "mongo.username",
        :mongo_passwd => "mongo.password"
    }

    attr_reader :settings

    # Creates a new instance of the MongoDB persistence adapter.
    # Expects a parsed YAML settings document as input.
    # Will create indexes on fields most frequently used in queries.
    def initialize(set)
      merge LOCALCONFIG

      @settings = set
      @uniq = config(:uniq_id)
      @mongo = Mongo::Connection.new(config(:mongo_host),
                                     config(:mongo_port))\
                                .db(config(:mongo_db))
      @enttodb = {
          :users => get_collection("users"),
          :commits => get_collection("commits"),
          :repos => get_collection("repos"),
          :followers => get_collection("followers"),
          :events => get_collection("events"),
          :org_members => get_collection("org_members"),
          :commit_comments => get_collection("commit_comments")
      }

      # Ensure that the necessary indexes exist
      ensure_index(:users, "login")
      ensure_index(:commits, "sha")
      ensure_index(:repos, "name")
      ensure_index(:followers, "follows")
      ensure_index(:org_members, "org")
      ensure_index(:commit_comments, "repo")
      ensure_index(:commit_comments, "user")
      ensure_index(:commit_comments, "commit_id")
    end


    def store(entity, data = {})
      super
      get_entity(entity).insert(data).to_s
    end

    def find(entity, query = {})
      super
      result = get_entity(entity).find(query)
      result.to_a.map { |r|
        r[@uniq] = r['_id'].to_s;
        r.to_h
      }
    end

    # Find the record identified by +id+ in +entity+
    def find_by_ext_ref_id(entity, id)
      super
      raise NotImplementedError
    end

    # Count the number of items returned by +query+
    def count(entity, query)
      super
      get_entity(entity).count(:query => query)
    end

    private

    def get_collection(col)
      @mongo.collection(col.to_s)
    end

    def get_entity(entity)
      col = @enttodb[entity]

      if col.nil?
        raise GHTorrentException.new("Mongo: Entity #{entity} not supported")
      end
      col
    end

    # Declare an index on +field+ for +collection+ if it does not exist
    def ensure_index(collection, field)
      col = @enttodb[collection]

      exists = col.index_information.find {|k,v|
        k == "#{field}_1"
      }

      if exists.nil?
        col.create_index(field, :background => true)
        STDERR.puts "Creating index on #{collection}(#{field})"
      end
    end

  end
end

class BSON::OrderedHash

  # Convert a BSON result to a +Hash+
  def to_h
    inject({}) do |acc, element|
      k, v = element;
      acc[k] = if v.class == BSON::OrderedHash then
                 v.to_h
               else
                 v
               end;
      acc
    end
  end
end