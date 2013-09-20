require 'mongo'
require 'ghtorrent/adapters/base_adapter'
require 'ghtorrent/bson_orderedhash'

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
        :mongo_passwd => "mongo.password",
        :mongo_replicas => "mongo.replicas"
    }

    IDXS = {
        :events                => %w(id),
        :users                 => %w(login),
        :commits               => %w(sha),
        :commit_comments       => %w(repo user commit_id),
        :repos                 => %w(name owner.login),
        :repo_labels           => %w(repo owner),
        :repo_collaborators    => %w(repo owner login),
        :followers             => %w(follows login),
        :org_members           => %w(org),
        :watchers              => %w(repo owner login),
        :forks                 => %w(repo owner id),
        :pull_requests         => %w(repo owner),
        :pull_request_comments => %w(repo owner pullreq_id id),
        :issues                => %w(repo owner number),
        :issue_events          => %w(repo owner issue_id id),
        :issue_comments        => %w(repo owner issue_id id)
    }

    attr_reader :settings

    # Creates a new instance of the MongoDB persistence adapter.
    # Expects a parsed YAML settings document as input.
    # Will create indexes on fields most frequently used in queries.
    def initialize(set)
      merge LOCALCONFIG

      @settings = set
      @uniq = config(:uniq_id)
    end

    def store(entity, data = {})
      super
      rescue_connection_failure do
        get_entity(entity).insert(data).to_s
      end
    end

    def find(entity, query = {})
      super
      result = rescue_connection_failure do
        get_entity(entity).find(query)
      end

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
      rescue_connection_failure do
        get_entity(entity).count(:query => query)
      end
    end

    def del(entity, query)
      super
      raise Exception 'No filter was specifed. Cowardily refusing to remove all entries' if query == {}
      get_entity(entity).remove(query)
    end

    def get_underlying_connection
      mongo
    end

    def close
      unless @mongo.nil?
        @mongo.close if @mongo.class == Mongo::ReplSetConnection
        @mongo.connection.close if @mongo.class == Mongo::Connection

        @mongo = nil
      end
    end

    private

    def get_collection(col)
      mongo.collection(col.to_s)
    end

    def get_entity(entity)
      case entity
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
        when :pull_request_comments
          get_collection("pull_request_comments")
        when :issues
          get_collection("issues")
        when :issue_comments
          get_collection("issue_comments")
        when :issue_events
          get_collection("issue_events")
        when :repo_labels
          get_collection("repo_labels")
      end
    end

    def mongo
      if @mongo.nil?

        replicas = config(:mongo_replicas)

        @mongo = if replicas.nil?
                   Mongo::Connection.new(config(:mongo_host),
                                         config(:mongo_port))\
                                    .db(config(:mongo_db))
                 else
                   repl_arr = replicas.strip.split(/ /).map{|x| "#{x}:#{config(:mongo_port)}"}
                   repl_arr << "#{config(:mongo_host)}:#{config(:mongo_port)}"
                   Mongo::ReplSetConnection.new(repl_arr, :read => :secondary)\
                                           .db(config(:mongo_db))
                 end

        stats = @mongo.stats
        init_db(@mongo) if stats['collections'] < ENTITIES.size + 2
        init_db(@mongo) if stats['indexes'] < IDXS.keys.size + ENTITIES.size

        @mongo
      else
        @mongo
      end
    end

    def init_db(mongo)
      ENTITIES.each {|x| mongo.collection(x.to_s)}

      # Ensure that the necessary indexes exist
      IDXS.each do |k,v|
        col = get_entity(k)
        name = v.join('_1_') + '_1'
        exists = col.index_information.find {|k,v| k == name}

        idx_fields = v.reduce({}){|acc, x| acc.merge({x => 1})}
        if exists.nil?
          col.create_index(idx_fields, :background => true)
          STDERR.puts "Creating index on #{collection}(#{v})"
        else
          STDERR.puts "Index on #{collection}(#{v}) exists"
        end

      end
    end

    def rescue_connection_failure(max_retries=60)
      retries = 0
      begin
        yield
      rescue Mongo::ConnectionFailure => ex
        retries += 1
        raise ex if retries > max_retries
        sleep(0.5)
        @mongo.refresh if @mongo.class == Mongo::ReplSetConnection
        retry
      end
    end
  end
end
