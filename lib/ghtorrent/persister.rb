module GHTorrent

  #
  module Persister

    ADAPTERS = {
      :mongo => GHTorrent::MongoPersister,
      :noop => GHTorrent::NoopPersister
    }

    # Factory method for retrieving persistence connections.
    # The +settings+ argument is a fully parsed YAML document
    # passed on to adapters. The available +adapter+ are :mongo and :noop
    def connect(adapter, settings)
      driver = ADAPTERS[adapter]
      driver.new(settings)
    end

  end
end