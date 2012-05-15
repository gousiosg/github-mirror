#require File.join(File.dirname(__FILE__), "adapters", "mongo_persister")
#require File.join(File.dirname(__FILE__), "adapters", "noop_persister")

module GHTorrent
  class Persister

    ENTITIES = [:users, :commits, :follows]

    ADAPTERS = {
        :mongo => GHTorrent::MongoPerister,
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