#!/usr/bin/env ruby

require 'ghtorrent'

class GHTFixIssueLabels < GHTorrent::Command

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


  def go
    @ght ||= GHTorrent::Mirror.new(settings)
    col = persister.get_underlying_connection[:issues]

    #repos = @ght.get_db.from(:projects, :users)\
    #                   .where(:projects__owner_id => :users__id)\
    #                   .select(:projects__name, :users__login).all

    #repos.each do |repo|
    #  begin
    #    @ght.ensure_labels(repo[:login], repo[:name])
    #  rescue
    #    logger.debug "Could not get labels for repo #{repo[:login]}/#{repo[:name]}"
    #  end
    #end
    @ght.get_db
    issues = lbls = 0
    col.find({'labels' => {'$ne' => '[]'}}, {:timeout => false}) do |cursor|
      cursor.each do |issue|
        issues += 1
        begin
          labels = issue['labels']
          unless labels.empty?
              added = @ght.ensure_issue_labels(issue['owner'], issue['repo'],
                                              issue['number'])
              lbls += added.size
              STDERR.write "\r Processed #{issues} issues, #{lbls} labels"
          end
        rescue StandardError => e
          logger.debug "Could not add labels to issue #{issue['owner']}/#{issue['repo']} -> #{issue['number']}"
          logger.debug "Reason: #{e}"
        end
      end
    end
  end
end

GHTFixIssueLabels.run
