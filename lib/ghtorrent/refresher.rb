require 'ghtorrent/api_client'
require 'ghtorrent/settings'
require 'ghtorrent/retriever'

module GHTorrent
  module Refresher

    def refresh_repo(owner, repo, db_entry)

      return db_entry if Time.now - db_entry[:updated_at] < 3600 * 24

      etag = db_entry[:etag]
      url = ghurl "repos/#{owner}/#{repo}"
      lu = last_updated(url, etag)
      debug "Repo #{owner}/#{repo} last updated: #{lu}, db_entry: #{db_entry[:updated_at]}"

      if lu > db_entry[:updated_at]
        fresh_repo = retrieve_repo(owner, repo, true)

        unless fresh_repo.nil?
          db.from(:projects).
              where(:id => db_entry[:id]).
              update(:etag => fresh_repo['etag'],
                     :updated_at => lu)

          info "Repo #{owner}/#{repo} updated at #{lu} (etag: #{fresh_repo['etag']})"
        end

        return db[:projects].first(:id => db_entry[:id])
      end

      db_entry
    end
  end
end
