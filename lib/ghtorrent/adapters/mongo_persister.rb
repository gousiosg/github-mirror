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
        :mongo_ssl  => "mongo.ssl",
        :mongo_replicas => "mongo.replicas"
    }

    IDXS = {
        :events                => %w(id),
        :users                 => %w(login),
        :commits               => %w(sha),
        :commit_comments       => %w(commit_id id),
        :repos                 => %w(name owner.login),
        :repo_labels           => %w(repo owner),
        :repo_collaborators    => %w(repo owner login),
        :followers             => %w(follows login),
        :org_members           => %w(org),
        :watchers              => %w(repo owner login),
        :forks                 => %w(repo owner id),
        :pull_requests         => %w(repo owner number),
        :pull_request_comments => %w(repo owner pullreq_id id),
        :issues                => %w(repo owner number),
        :issue_events          => %w(repo owner issue_id id),
        :issue_comments        => %w(repo owner issue_id id),
        :geo_cache             => %w(key),
        :pull_request_commits  => %w(sha),
        :topics                => %w(repo owner)
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
      mongo[entity].insert_one(data).to_s
    end

    def replace(entity, query, new_entry, upsert = true)
      check_entity_exists(entity)		
      r = mongo[entity].update_one(query, new_entry, {:upsert => upsert}) 
      r
    end

    def find(entity, query = {})
      super
      mongo[entity].
          find(query).
          to_a.
          map { |r| r.to_h }
    end

    # Count the number of items returned by +query+
    def count(entity, query)
      super
      mongo[entity].count(:query => query)
    end

    def del(entity, query)
      super
      raise StandardError 'No filter was specified. Cowardly refusing to remove all entries' if query == {}
      r = mongo[entity].delete_many(query)
      r.n
    end

    def upsert(entity, query = {}, new_entry)
      super
      r = del(entity, query)
      store(entity, new_entry)
      r
    end

    def get_underlying_connection
      mongo
    end

    def close
      unless @mongo.nil?
        @mongo.disconnect!
        @mongo = nil
      end
    end

    private

    def mongo
      return @mongo.database unless @mongo.nil?

      uname = config(:mongo_username)
      passwd = config(:mongo_passwd)
      host = config(:mongo_host)
      port = config(:mongo_port)
      db = config(:mongo_db)

      replicas = config(:mongo_replicas)
      replicas = if replicas.nil? then
                   ''
                 else
                   ',' + replicas.strip.gsub(' ', ',')
                 end

      ssl = case config(:mongo_ssl)
              when 'true', 'True', 't', true
                true
              else
                false
            end

      constring = if uname.nil?
                    "mongodb://#{host}:#{port}#{replicas}/#{db}?ssl=#{ssl}"
                  else
                    "mongodb://#{uname}:#{passwd}@#{host}:#{port}#{replicas}/#{db}?ssl=#{ssl}"
                  end

      Mongo::Logger.logger.level = Logger::WARN
      @mongo = Mongo::Client.new(constring)

      dbs = @mongo.list_databases
      if dbs.find { |x| x['name'] == db }.nil?
        init_db(@mongo.database)
      end

      @mongo.database

    end

    def init_db(mongo)
      ENTITIES.each do |x|
        if mongo.list_collections.find { |c| c['name'] == x.to_s }.nil?
          STDERR.puts "Creating collection #{x}"
          mongo[x].create
        end
      end

      # Ensure that the necessary indexes exist
      IDXS.each do |k, v|
        col = mongo[k.intern]
        name = v.join('_1_') + '_1'
        exists = col.indexes.find { |k, v| k == name }

        idx_fields = v.reduce({}) { |acc, x| acc.merge({x => 1}) }
        if exists.nil?
          col.indexes.create_one(idx_fields, :background => true)
          STDERR.puts "Creating index on #{col}(#{v})"
        else
          STDERR.puts "Index on #{col}(#{v}) exists"
        end
      end
    end

  end
end
