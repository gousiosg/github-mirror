module GHTorrent
  class NoopPersister

    def store(entity, data = {})
      #Nothing to see here
    end

    def retrieve(entity, query = {})
      #Nothing to see here
    end

  end
end