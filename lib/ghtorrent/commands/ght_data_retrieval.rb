require 'rubygems'
require 'amqp'
require 'json'
require 'pp'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'

class GHTDataRetrieval < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Logging

  def parse(msg)
    JSON.parse(msg)
  end

  def PushEvent(data)
    data['payload']['commits'].each do |c|
      url = c['url'].split(/\//)

      ghtorrent.get_commit url[4], url[5], url[7]
    end
  end

  def WatchEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    watcher = data['actor']['login']
    created_at = data['created_at']

    ghtorrent.get_watcher owner, repo, watcher, created_at
  end

  def FollowEvent(data)
    follower = data['actor']['login']
    followed = data['payload']['target']['login']
    created_at = data['created_at']

    ghtorrent.get_follower(follower, followed, created_at)
  end

  def MemberEvent(data)
    owner = data['actor']['login']
    repo = data['repo']['name'].split(/\//)[1]
    new_member = data['payload']['member']['login']
    created_at = data['created_at']

    ghtorrent.get_project_member(owner, repo, new_member, created_at)
  end

  def CommitCommentEvent(data)
    user = data['actor']['login']
    repo = data['repo']['name'].split(/\//)[1]
    id = data['payload']['comment']['id']

    ghtorrent.get_commit_comment(user, repo, id)
  end

  def PullRequestEvent(data)
    owner = data['payload']['pull_request']['base']['repo']['owner']['login']
    repo = data['payload']['pull_request']['base']['repo']['name']
    pullreq_id = data['payload']['number']
    action = data['payload']['action']
    created_at = data['created_at']

    ghtorrent.get_pull_request(owner, repo, pullreq_id, action, created_at)
  end

  def ForkEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    fork_id = data['payload']['forkee']['id']

    ghtorrent.get_fork(owner, repo, fork_id)
  end

  def PullRequestReviewCommentEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    comment_id = data['payload']['comment']['id']
    pullreq_id = data['payload']['comment']['_links']['pull_request']['href'].split(/\//)[-1]

    ghtorrent.get_pullreq_comment(owner, repo, pullreq_id, comment_id)
  end

  def IssuesEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    issue_id = data['payload']['issue']['number']

    ghtorrent.get_issue(owner, repo, issue_id)
  end

  def IssueCommentEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    issue_id = data['payload']['issue']['number']
    comment_id = data['payload']['comment']['id']

    ghtorrent.get_issue_comment(owner, repo, issue_id, comment_id)
  end

  def handlers
    %w(PushEvent WatchEvent FollowEvent MemberEvent
        CommitCommentEvent PullRequestEvent ForkEvent
        PullRequestReviewCommentEvent IssuesEvent IssueCommentEvent)
    #%w(PullRequestEvent)
  end

  def prepare_options(options)
    options.banner <<-BANNER
Retrieves events from queues and processes them through GHTorrent
#{command_name} [options]

#{command_name} options:
    BANNER

    options.opt :filter,
                'Only process messages for repos in the provided file',
                :short => 'f', :type => String
  end

  def validate
    super
    Trollop::die "Filter file does not exist" if options[:filter] and not File.exist?(options[:filter])
  end

  def logger
    ghtorrent.logger
  end

  def ghtorrent
    @gh ||= GHTorrent::Mirror.new(@settings)
    @gh
  end

  def go
    filter = Array.new

    if options[:filter]
      File.open(options[:filter]).each { |l|
        next if l.match(/^ *#/)
        parts = l.split(/ /)
        next if parts.size < 2
        debug "GHTDataRetrieval: Filtering events by #{parts[0] + "/" + parts[1]}"
        filter << parts[0] + "/" + parts[1]
      }
    end

    # Graceful exit
    Signal.trap('INT') {
      info "GHTDataRetrieval: Received SIGINT, exiting"
      AMQP.stop { EM.stop }
    }
    Signal.trap('TERM') {
      info "GHTDataRetrieval: Received SIGTERM, exiting"
      AMQP.stop { EM.stop }
    }

    AMQP.start(:host => config(:amqp_host),
               :port => config(:amqp_port),
               :username => config(:amqp_username),
               :password => config(:amqp_password)) do |connection|

      channel = AMQP::Channel.new(connection)
      channel.prefetch(config(:amqp_prefetch))
      exchange = channel.topic(config(:amqp_exchange), :durable => true,
                               :auto_delete => false)

      handlers.each { |h|
        queue = channel.queue("#{h}s", {:durable => true})\
                       .bind(exchange, :routing_key => "evt.#{h}")

        info "GHTDataRetrieval: Binding handler #{h} to routing key evt.#{h}"

        queue.subscribe(:ack => true) do |headers, msg|
          begin
            data = parse(msg)
            info "GHTDataRetrieval: Processing event: #{data['type']}-#{data['id']}"

            unless options[:filter].nil?
              if filter.include?(data['repo']['name'])
                send(h, data)
              else
                info "GHTDataRetrieval: Repo #{data['repo']['name']} not in process list. Ignoring event #{data['type']}-#{data['id']}"
              end
            else
              send(h, data)
            end
            headers.ack
            info "GHTDataRetrieval: Processed event: #{data['type']}-#{data['id']}"
          rescue Exception => e
            # Give a message a chance to be reprocessed
            if headers.redelivered?
              data = parse(msg)
              warn "GHTDataRetrieval: Could not process event: #{data['type']}-#{data['id']}"
              headers.reject(:requeue => false)
            else
              headers.reject(:requeue => true)
            end

            STDERR.puts e
            STDERR.puts e.backtrace.join("\n")
          end
        end
      }
    end
  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
