require 'rubygems'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/command'
require 'ghtorrent/retriever'

class GHTRetrieveRepo < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister
  include GHTorrent::EventProcessing

  def prepare_options(options)
    options.banner <<-BANNER
An efficient way to get all data for a single repo

#{command_name} [options] owner repo

    BANNER
    options.opt :no_events, 'Skip retrieving events', :default => false
    options.opt :no_entities, 'Skip retrieving entities', :default => false

    options.opt :only_stage, "Only do the provided stage of entity retrieval (one of: #{stages.join(',')})",
                :type => String
    options.opt :exclude_events, 'Comma separated list of event types to exclude from processing',
                :type => String
  end

  def validate
    super
    Trollop::die 'Two arguments are required' unless args[0] && !args[0].empty?

    unless options[:exclude_events].nil?
      @exclude_event_types = options[:exclude_events].split(/,/)
    else
      @exclude_event_types = []
    end

    unless options[:only_stage].nil?
      Trollop::die("Not a valid function: #{options[:only_stage]}") unless stages.include? options[:only_stage]
    end

  end

  def stages
    %w(ensure_commits ensure_forks ensure_pull_requests
       ensure_issues ensure_watchers ensure_labels) #ensure_project_members
  end


  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def ext_uniq
    @ext_uniq ||= config(:uniq_id)
    @ext_uniq
  end

  def ghtorrent
    @ghtorrent ||= TransactedGHTorrent.new(settings)
    @ghtorrent
  end

  def go
    self.settings = override_config(settings, :mirror_history_pages_back, 1000)
    user_entry = ghtorrent.transaction{ghtorrent.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{ARGV[0]}"
    end

    user = user_entry[:login]

    repo_entry = ghtorrent.transaction{ghtorrent.ensure_repo(ARGV[0], ARGV[1])}

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{ARGV[0]}/#{ARGV[1]}"
    end

    repo = repo_entry[:name]

    unless options[:no_entities_given]
      if options[:only_stage].nil?
        stages.each do |x|
          ghtorrent.send(x, user, repo)
        end
      else
        ghtorrent.send(options[:only_stage], user, repo)
      end
    end

    # Process repo events
    unless options[:no_events_given]
      get_repo_events(ARGV[0], ARGV[1]).each do |event|
        begin
          unless @exclude_event_types.include? event['type']
            send(event['type'], event)
          end
        rescue Exception => e
           puts "Could not process event #{event['type']}-#{event['id']}: #{e.message}"
        end
      end
    end

  end
end
