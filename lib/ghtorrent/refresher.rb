require 'ghtorrent/api_client'
require 'ghtorrent/settings'
require 'ghtorrent/retriever'

module GHTorrent
  module Refresher

    def refresh_repo(owner, repo, db_entry)

      now = Time.now
      return db_entry if now.to_i - db_entry[:updated_at].to_i < 3600 * 24 * 10 # 10 days

        fresh_repo = retrieve_repo(owner, repo, true)

        unless fresh_repo.nil?
          db.from(:projects).
              where(:id => db_entry[:id]).
              update(:updated_at => date(now))

          info "Repo #{owner}/#{repo} updated #{now}, previous update: #{db_entry[:updated_at]})"
        end

        return db[:projects].first(:id => db_entry[:id])
    end
  end
end
