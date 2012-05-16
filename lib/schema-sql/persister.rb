module GHTorrent
  class Persister

    ENTITIES = [:users, :commits, :followers, :repos]

    ADAPTERS = {
        :mongo => GHTorrent::MongoPersister,
        :noop => GHTorrent::NoopPersister
    }

    def initialize(adapter, settings)
      driver = ADAPTERS[adapter]
      @persister = driver.new(settings)
    end

    # Stores data into entity. Returns unique key for each
    # stored entry
    def store(entity, data = {})
      unless ENTITIES.include?(entity)
        throw GHTorrentException.new("Entity #{entity} not known")
      end

      @persister.store(entity, data)
    end


    # Stores data into entity. Returns the matched rows
    # as an array of hashes.
    def retrieve(entity, query = {})
      unless ENTITIES.include?(entity)
        throw GHTorrentException.new("Entity #{entity} not known")
      end

      @persister.retrieve(entity, query)
    end
  end
end