module GHTorrent
  class Persister

    ENTITIES = [:users, :commits, :follows]

    ADAPTERS = {
        :mongo => GHTorrent::MongoPersister,
        :noop  => GHTorrent::NoopPersister
    }

    def initialize(adapter)
      driver = ADAPTERS[adapter]
      @persister = driver.new
    end

    # Stores data into entity. Returns unique key for each
    # stored entry
    def store(entity, data = {})
      @persister.store(entity, data)
    end


    # Stores data into entity. Returns the matched rows
    # as an array of hashes.
    def retrieve(entity, query = {})
      @persister.retrieve(entity, query)
    end
  end
end