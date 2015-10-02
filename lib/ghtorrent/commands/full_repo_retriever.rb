module GHTorrent
  module Commands
    # Defines a process to download the full data available for a single user
    module FullRepoRetriever

      include GHTorrent::Retriever
      include GHTorrent::Settings
      include GHTorrent::EventProcessing

      def stages
        %w(ensure_commits ensure_forks ensure_pull_requests
       ensure_issues ensure_watchers ensure_labels ensure_languages) #ensure_project_members
      end

      def options
        raise('Unimplemented')
      end

      def settings
        raise('Unimplemented')
      end

      def supported_options(options)
        options.opt :no_events, 'Skip retrieving events', :default => false
        options.opt :no_entities, 'Skip retrieving entities', :default => false

        options.opt :only_stage, "Only do the provided stage of entity retrieval (one of: #{stages.join(',')})",
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
          Trollop::die("Not a valid function: #{options[:only_stage]}") unless stages.include? options[:only_stage]
        end

      end

      def ght
        @ghtorrent ||= TransactedGHTorrent.new(settings)
        @ghtorrent
      end

      def retrieve_repo(owner, repo)
        self.settings = override_config(settings, :mirror_history_pages_back, 1000)
        user_entry = ght.transaction { ght.ensure_user(owner, false, false) }

        if user_entry.nil?
          Trollop::die "Cannot find user #{owner}"
        end

        user = user_entry[:login]

        repo_entry = ght.transaction { ght.ensure_repo(owner, repo) }

        if repo_entry.nil?
          Trollop::die "Cannot find repository #{owner}/#{repo}"
        end

        unless options[:no_entities_given]
          begin
            if options[:only_stage].nil?
              stages.each do |x|
                stage = x
                ght.send(x, user, repo)
              end
            else
              stage = options[:only_stage]
              ght.send(options[:only_stage], user, repo)
            end
          rescue StandardError => e
            warn("Error processing #{stage} for #{owner}/#{repo}: #{$!}")
            warn("Exception trace #{e.backtrace.join("\n")}")
          end
        end

        # Process repo events
        unless options[:no_events_given]
          events = get_repo_events(owner, repo[:name]).sort { |e| e['id'].to_i }
          events.each do |event|
            begin
              next if @exclude_event_types.include? event['type']
              next if options[:events_after_given] and event['id'].to_i <= options[:events_after]
              next if options[:events_before_given] and event['id'].to_i >= options[:events_before]

              send(event['type'], event)
              puts "Processed event #{event['type']}-#{event['id']}"
            rescue StandardError => e
              puts "Could not process event #{event['type']}-#{event['id']}: #{e.message}"
            end
          end
        end
      end
    end
  end
end