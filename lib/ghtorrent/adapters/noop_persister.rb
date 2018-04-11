module GHTorrent

  # Persister adapter that does not store any data.
  class NoopPersister < BaseAdapter

    def initialize(settings)
    end

    def store(entity, data = {})
      super
      #Nothing to see here
      0
    end

    def find(entity, query = {})
      super
      #Nothing to see here
      []
    end

    def upsert(entity, query = {}, entry = nil)
      super
      #Nothing to see here
      []
    end

    def get_id
      0
    end
  end
end
