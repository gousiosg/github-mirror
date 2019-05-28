require 'ghtorrent/transacted_gh_torrent'

module GHTorrent
  module Commands
    # Defines a process to download the full data available for a single user
    module FullRepoRetriever

      include GHTorrent::Retriever
      include GHTorrent::Settings
      include GHTorrent::EventProcessing

      def stages
        %w(ensure_commits ensure_topics ensure_languages ensure_pull_requests
         ensure_issues ensure_watchers ensure_labels ensure_forks)
      end

      def settings
        raise('Unimplemented')
      end

      def options
        raise('Unimplemented')
      end

      def ght
        @ghtorrent ||= TransactedGHTorrent.new(settings)
        @ghtorrent
      end

      def persister
        ght.persister
      end

      def supported_options(options)
        options.opt :no_events, 'Skip retrieving events', :default => false
        options.opt :no_entities, 'Skip retrieving entities', :default => false

        options.opt :only_stage, "Only do the provided stage of entity retrieval (one of: #{stages.join(', ')})",
                    :type => String
        options.opt :exclude_events, 'Comma separated list of event types to exclude from processing',
                    :type => String
        options.opt :events_after, 'Process all events later than the provided event id',
                    :type => Integer
        options.opt :events_before, 'Process all events earlier than the provided event id',
                    :type => Integer
      end

      def validate_options
        unless options[:exclude_events].nil?
          @exclude_event_types = options[:exclude_events].split(/,/)
        else
          @exclude_event_types = []
        end

        unless options[:only_stage].nil?
          Optimist::die("Not a valid function: #{options[:only_stage]}") unless stages.include? options[:only_stage]
        end

      end

      def retrieve_full_repo(owner, repo)
        start_time = Time.now
        info "Start fetching: #{owner}/#{repo}"

        user_entry = ght.transaction { ght.ensure_user(owner, false, false) }
        if user_entry.nil?
          warn "Skip: #{owner}/#{repo}. Owner: #{owner} not found"
          return
        end

        user = user_entry[:login]
        repo_entry = ght.transaction{ght.ensure_repo(owner, repo)}

        if repo_entry.nil?
          warn "Skip: #{owner}/#{repo}. Repo: #{repo} not found"
          return
        end

        # Update project details
        stage = nil
        unless options[:no_entities_given]
          begin
            if options[:only_stage].nil?
              ght.stages.each do |x|
                stage_time = Time.now
                stage = x
                ght.send(x, user, repo)
                info "Stage: #{stage} completed, Repo: #{owner}/#{repo}, Time: #{Time.now.to_ms - stage_time.to_ms} ms"
              end

              ght.db.from(:projects).where(:id => repo_entry[:id]).update(:updated_at => Time.now)
            else
              stage_time = Time.now
              stage = options[:only_stage]
              ght.send(options[:only_stage], user, repo)
              info "Stage: #{stage} completed, Repo: #{owner}/#{repo}, Time: #{Time.now.to_ms - stage_time.to_ms} ms"
            end
          rescue StandardError => e
            error("Error in stage: #{stage}, Repo: #{owner}/#{repo}, Message: #{$!}")
            puts e.backtrace
            return
          end
        end

        # Process repo events
        unless options[:no_events_given]
          events = get_repo_events(owner, repo).sort { |e| e['id'].to_i }
          events.each do |event|
            begin
              next if not @exclude_event_types.nil? and @exclude_event_types.include? event['type']
              next if options[:events_after_given] and event['id'].to_i <= options[:events_after]
              next if options[:events_before_given] and event['id'].to_i >= options[:events_before]

              send(event['type'], event)
              info "Success processing event. Type: #{event['type']}, ID: #{event['id']}"
            rescue StandardError => e
              warn "Error processing event. Type: #{event['type']}, ID: #{event['id']}"
            end
          end
        end
        info "Done fetching: #{owner}/#{repo}, Time: #{Time.now.to_ms - start_time.to_ms} ms"
      end
    end
  end
end
