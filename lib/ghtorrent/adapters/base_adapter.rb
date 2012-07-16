module GHTorrent

  class BaseAdapter

    ENTITIES = [:users, :commits, :followers, :repos, :events, :org_members,
        :commit_comments, :repo_collaborators, :watchers
    ]

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

    # Count the number of entries returned by +query+ without retrieving them.
    # The +query+ can be any query supported by +find+.
    def count(entity, query = {})
      unless ENTITIES.include?(entity)
        throw GHTorrentException.new("Perister: Entity #{entity} not known")
      end
    end
  end
end