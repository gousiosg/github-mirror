require 'mongo'
require 'ghtorrent/adapters/base_adapter'

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

      # Ensure that the necessary indexes exist
      ensure_index(:events, "id")
      ensure_index(:users, "login")
      ensure_index(:commits, "sha")
      ensure_index(:repos, "name")
      ensure_index(:followers, "follows")
      ensure_index(:org_members, "org")
      ensure_index(:commit_comments, "repo")
      ensure_index(:commit_comments, "user")
      ensure_index(:commit_comments, "commit_id")
      ensure_index(:repo_collaborators, "repo")
      ensure_index(:repo_collaborators, "owner")
      ensure_index(:repo_collaborators, "login")
      ensure_index(:watchers, "repo")
      ensure_index(:watchers, "owner")
      ensure_index(:watchers, "login")
      ensure_index(:pull_requests, "repo")
      ensure_index(:pull_requests, "owner")
      ensure_index(:forks, "repo")
      ensure_index(:forks, "owner")
      ensure_index(:forks, "id")

    end

    def store(entity, data = {})
      super
      copy = get_entity(entity).insert(data).to_s
      close
      copy
    end

    def find(entity, query = {})
      super
      result = get_entity(entity).find(query)

      copy = result.to_a.map { |r|
        r[@uniq] = r['_id'].to_s;
        r.to_h
      }
      close
      copy.each {|x|
        if x[@uniq].nil?
          raise "#{@uniq} is null"
        end
      }
      copy
    end

    # Find the record identified by +id+ in +entity+
    def find_by_ext_ref_id(entity, id)
      super
      raise NotImplementedError
    end

    # Count the number of items returned by +query+
    def count(entity, query)
      super
      copy = get_entity(entity).count(:query => query)
      close
      copy
    end

    private

    def get_collection(col)
      mongo.collection(col.to_s)
    end

    def get_entity(entity)

      col = case entity
              when :users
                get_collection("users")
              when :commits
                get_collection("commits")
              when :repos
                get_collection("repos")
              when :followers
                get_collection("followers")
              when :org_members
                get_collection("org_members")
              when :events
                get_collection("events")
              when :commit_comments
                get_collection("commit_comments")
              when :repo_collaborators
                get_collection("repo_collaborators")
              when :watchers
                get_collection("watchers")
              when :pull_requests
                get_collection("pull_requests")
              when :forks
                get_collection("forks")
            end

      if col.nil?
        raise GHTorrentException.new("Mongo: Entity #{entity} not supported")
      end
      col
    end

    def mongo
      @mongo ||= Mongo::Connection.new(config(:mongo_host),
                                     config(:mongo_port))\
                                .db(config(:mongo_db))
      @mongo
    end

    def close
      unless @mongo.nil?
        @mongo.connection.close
        @mongo = nil
      end
    end

    # Declare an index on +field+ for +collection+ if it does not exist
    def ensure_index(collection, field)
      col = get_entity(collection)

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