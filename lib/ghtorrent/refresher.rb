require 'ghtorrent/api_client'
require 'ghtorrent/settings'
require 'ghtorrent/retriever'

module GHTorrent
  module Refresher

    def refresh_repo(owner, repo, db_entry)

      return db_entry if Time.now.to_i - db_entry[:updated_at].to_i > 3600 * 24

      etag = db_entry[:etag]
      url = ghurl "repos/#{owner}/#{repo}"

      if last_updated(url, etag).to_i > db_entry[:updated_at].to_i
        fresh_repo = retrieve_repo(owner, repo, true)

        unless fresh_repo.nil?
          db.from(:projects).
              where(:id => db_entry[:id]).
              update(:etag => fresh_repo['etag'])
        end

        return db[:projects].first(:id => db_entry[:id])
      end

      db_entry
    end
  end
end