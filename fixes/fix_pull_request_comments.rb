#!/usr/bin/env ruby

require 'ghtorrent'

class GHTFixPullReqComments < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def logger
    @ght.logger
  end

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def ght
    @ght ||= GHTorrent::Mirror.new(settings)
    @ght
  end

  def db
    @db ||= ght.get_db
    @db
  end

  def go
    db
    col = persister.get_underlying_connection[:pull_request_comments]

    processed = duplicates = no_pullreq_id = sql_upd = 0
    col.distinct('id').each do |id|
      begin
        processed += 1

        # 1. Select a comment
        comments = col.find({'id' => id}, {:sort => [['_id' => Mongo::ASCENDING]]}).to_a

        if comments.size == 1
          next
        end

        duplicates += (comments.size - 1)
        selected = comments.last

        issue_id = selected['issue_id']
        pullreq_id = selected['pullreq_id']

        # 2. Make sure that only the pull_req_field exists
        if pullreq_id.nil?
          no_pullreq_id += 1
          if issue_id.nil?
            log.warn("Comment: #{id}: No issue id or pullreq id")
            next
          else
            selected['pullreq_id'] = issue_id
            selected.delete('issue_id')
          end
        else
          unless issue_id.nil?
            selected.delete('issue_id')
          end
        end

        # Make sure the pullreq_id field is an int
        selected['pullreq_id'] = selected['pullreq_id'].to_i

        # 3. Remove all comments with this id from Mongo
        col.remove('id' => id)

        # 4. Insert selected comment
        ext_ref_id = col.insert(selected)

        # 5. Use _id to update ext_ref_id field in SQL
        upd = db[:pull_request_comments].\
                where(:comment_id => id).\
                update(:ext_ref_id => ext_ref_id.to_s)

        if upd == 0
          ght.ensure_pullreq_comment(selected['owner'], selected['repo'],
                                     selected['pullreq_id'], id)
          upd += 1
        end
        sql_upd += upd
        logger.info("Processed pull request comment: #{id}")
      rescue StandardError => e
        logger.warn("Cannot process comment #{id}: #{e.message}")
        #raise e
      ensure
        STDERR.write("\r Processed #{processed} comments, #{duplicates} duplicates, #{no_pullreq_id} no pullreq id, #{sql_upd} updated in sql")
      end

    end
  end
end

GHTFixPullReqComments.run
