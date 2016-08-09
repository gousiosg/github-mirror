module GHTorrent

  class BaseAdapter

    ENTITIES = [:users, :commits, :followers, :repos, :events, :org_members,
        :commit_comments, :repo_collaborators, :watchers, :pull_requests,
        :forks, :pull_request_comments, :issue_comments, :issues, :issue_events,
        :repo_labels, :geo_cache, :pull_request_commits
    ].sort

    # Stores +data+ into +entity+. Returns a unique key for the stored entry.
    def store(entity, data = {})
      if bsearch(ENTITIES, entity).nil?
        raise "Perister: Entity #{entity} not known"
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
      if bsearch(ENTITIES, entity).nil?
        raise "Perister: Entity #{entity} not known"
      end
    end

    # Count the number of entries returned by +query+ without retrieving them.
    # The +query+ can be any query supported by +find+.
    def count(entity, query = {})
      if bsearch(ENTITIES, entity).nil?
        raise "Perister: Entity #{entity} not known"
      end
    end

    # Delete the entities matched by the query and return the
    # number of entities deleted
    def del(entity, query = {})
      if bsearch(ENTITIES, entity).nil?
        raise "Perister: Entity #{entity} not known"
      end
    end

    # Add or update the entry matched by the query and return
    # the number of entities added or updated
    def upsert(entity, query = {}, new_entry)
      if bsearch(ENTITIES, entity).nil?
        raise "Perister: Entity #{entity} not known"
      end
    end

    # Get a raw connection to the underlying data store. The connection is
    # implementaiton dependent.
    def get_underlying_connection
      raise "Unimplemented"
    end

    # Close the current connection and release any held resources
    def close
      raise "Unimplemented"
    end

    private

    def bsearch( arr, t,from=0, to=nil)
      if to.nil?
        to = arr.size - 1
      end
      return if from > to
      mid = (from + to ) / 2
      if arr[mid] > t
        bsearch arr, t, 0, mid - 1
      elsif arr[mid] < t
        bsearch arr, t, mid + 1, to
      else
        mid
      end
    end
  end
end