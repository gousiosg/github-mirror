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
#``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
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
        throw GHTorrentException.new("Perister: Entity #{entity} not known")
      end

      @persister.store(entity, data)
    end


    # Stores data into entity. Returns the matched rows
    # as an array of hashes.
    def retrieve(entity, query = {})
      unless ENTITIES.include?(entity)
        throw GHTorrentException.new("Perister: Entity #{entity} not known")
      end

      @persister.retrieve(entity, query)
    end
  end
end