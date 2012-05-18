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
# AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
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

  class BaseAdapter

    ENTITIES = [:users, :commits, :followers, :repos, :events]


    # Stores +data+ into +entity+. Returns a unique key for the stored entry.
    def store(entity, data = {})
      unless ENTITIES.include?(entity)
        throw GHTorrentException.new("Perister: Entity #{entity} not known")
      end
    end

    # Retrieves rows from +entity+ matching the provided +query+.
    # The +query+
    # is performed on the Github API JSON results. For example, given the
    # following JSON object format:
    #
    #   {
    #      commit: {
    #        sha: "23fa34aa442456"
    #      }
    #      author: {
    #        name: {
    #          real_name: "foo"
    #          given_name: "bar"
    #        }
    #      }
    #      created_at: "1980-12-30T22:25:25"
    #   }
    #
    # to query for matching +sha+, pass to +query+
    #
    #   {'commit.sha' => 'a_value'}
    #
    # to query for real_name's matching an argument, pass to +query+
    #
    #   {'author.name.real_name' => 'a_value'}
    #
    # to query for both a specific sha and a specific creation time
    #
    #   {'commit.sha' => 'a_value', 'created_at' => 'other_value'}
    #
    # The persister adapter must translate the query to the underlying data
    # storage engine query capabilities.
    #
    # The results are returned as an array of hierarchical maps, one for each
    # matching JSON object.
    def find(entity, query = {})
      unless ENTITIES.include?(entity)
        throw GHTorrentException.new("Perister: Entity #{entity} not known")
      end
    end

    # Find the record identified by +id+ in +entity+
    def find_by_ext_ref_id(entity, id)
      unless ENTITIES.include?(entity)
        throw GHTorrentException.new("Perister: Entity #{entity} not known")
      end
    end
  end
end