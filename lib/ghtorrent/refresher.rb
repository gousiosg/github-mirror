require 'ghtorrent/api_client'
require 'ghtorrent/settings'
require 'ghtorrent/retriever'

module GHTorrent
  module Refresher

    def refresh_repo(owner, repo, db_entry)

      now = Time.now
      return db_entry if now.to_i - db_entry[:updated_at].to_i < 3600 * 24

      etag = db_entry[:etag]
      url = ghurl "repos/#{owner}/#{repo}"
      lu = last_updated(url, etag)
      debug "Repo #{owner}/#{repo} last_modified: #{lu}, db_entry: #{db_entry[:updated_at]}"

      if lu.to_i >= db_entry[:updated_at].to_i
        fresh_repo = retrieve_repo(owner, repo, true)

        unless fresh_repo.nil?
          db.from(:projects).
              where(:id => db_entry[:id]).
              update(:etag => fresh_repo['etag'],
                     :updated_at => date(now))

          info "Repo #{owner}/#{repo} updated #{now} (etag: #{fresh_repo['etag']}, last_modified: #{lu})"
        end

        return db[:projects].first(:id => db_entry[:id])
      end

      db_entry
    end
  end
end
