require 'rubygems'
require 'bunny'
require 'json'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'

class GHTDataRetrieval < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Logging
  include GHTorrent::Persister

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def parse(msg)
    JSON.parse(msg)
  end

  def PushEvent(data)
    data['payload']['commits'].each do |c|
      url = c['url'].split(/\//)

      unless url[7].match(/[a-f0-9]{40}$/)
        error "Ignoring commit #{sha}"
        return
      end

      ghtorrent.ensure_commit(url[5], url[7], url[4])
    end
  end

  def WatchEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    watcher = data['actor']['login']
    created_at = data['created_at']

    ghtorrent.ensure_watcher(owner, repo, watcher, created_at)
  end

  def FollowEvent(data)
    follower = data['actor']['login']
    followed = data['payload']['target']['login']
    created_at = data['created_at']

    ghtorrent.ensure_user_follower(followed, follower, created_at)
  end

  def MemberEvent(data)
    owner = data['actor']['login']
    repo = data['repo']['name'].split(/\//)[1]
    new_member = data['payload']['member']['login']
    date_added = data['created_at']

    ghtorrent.transaction do
      pr_members = ghtorrent.get_db[:project_members]
      project = ghtorrent.ensure_repo(owner, repo)
      new_user = ghtorrent.ensure_user(new_member, false, false)

      if project.nil? or new_user.nil?
        return
      end

      memb_exist = pr_members.first(:user_id => new_user[:id],
                                    :repo_id => project[:id])

      if memb_exist.nil?
        added = if date_added.nil?
                  max(project[:created_at], new_user[:created_at])
                else
                  date_added
                end

        pr_members.insert(
            :user_id => new_user[:id],
            :repo_id => project[:id],
            :created_at => ghtorrent.date(added)
        )
        info "Added project member #{repo} -> #{new_member}"
      else
        debug "Project member #{repo} -> #{new_member} exists"
      end
    end

  end

  def CommitCommentEvent(data)
    user = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    id = data['payload']['comment']['id']
    sha = data['payload']['comment']['commit_id']

    ghtorrent.ensure_commit_comment(user, repo, sha, id)
  end

  def PullRequestEvent(data)
    owner = data['payload']['pull_request']['base']['repo']['owner']['login']
    repo = data['payload']['pull_request']['base']['repo']['name']
    pullreq_id = data['payload']['number']
    action = data['payload']['action']
    actor = data['actor']['login']
    created_at = data['created_at']

    ghtorrent.ensure_pull_request(owner, repo, pullreq_id, true, true, true,
                                  action, actor, created_at)
  end

  def ForkEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    fork_id = data['payload']['forkee']['id']

    forkee_owner = data['payload']['forkee']['owner']['login']
    forkee_repo = data['payload']['forkee']['name']

    ghtorrent.ensure_fork(owner, repo, fork_id)
    ghtorrent.ensure_repo_recursive(forkee_owner, forkee_repo, true)
  end

  def PullRequestReviewCommentEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    comment_id = data['payload']['comment']['id']
    pullreq_id = data['payload']['comment']['_links']['pull_request']['href'].split(/\//)[-1]

    ghtorrent.ensure_pullreq_comment(owner, repo, pullreq_id, comment_id)
  end

  def IssuesEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    issue_id = data['payload']['issue']['number']

    ghtorrent.ensure_issue(owner, repo, issue_id)
  end

  def IssueCommentEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    issue_id = data['payload']['issue']['number']
    comment_id = data['payload']['comment']['id']

    ghtorrent.ensure_issue_comment(owner, repo, issue_id, comment_id)
  end

  def CreateEvent(data)
    owner = data['repo']['name'].split(/\//)[0]
    repo = data['repo']['name'].split(/\//)[1]
    return unless data['payload']['ref_type'] == 'repository'

    ghtorrent.ensure_repo(owner, repo)
    ghtorrent.ensure_repo_recursive(owner, repo, false)
  end

  def handlers
    %w(PushEvent WatchEvent FollowEvent MemberEvent CreateEvent
        CommitCommentEvent PullRequestEvent ForkEvent
        PullRequestReviewCommentEvent IssuesEvent IssueCommentEvent)
    #%w(ForkEvent)
  end

  def prepare_options(options)
    options.banner <<-BANNER
Retrieves events from queues and processes them through GHTorrent.
If event_id is provided, only this event is processed.
#{command_name} [event_id]
    BANNER

  end

  def validate
    super
  end

  def logger
    ghtorrent.logger
  end

  def ghtorrent
    #@gh ||= GHTorrent::Mirror.new(@settings)
    @gh ||= TransactedGHTorrent.new(settings)
    @gh
  end

  def retrieve_event(evt_id)
    event = persister.get_underlying_connection[:events].find_one('id' => evt_id)
    event.delete '_id'
    data = parse(event.to_json)
    debug "Processing event: #{data['type']}-#{data['id']}"
    data
  end

  def go

    unless ARGV[0].nil?
      event = retrieve_event(ARGV[0])

      if event.nil?
        warn "No event with id: #{ARGV[0]}"
      else
        send(event['type'], event)
      end
      return
    end

    conn = Bunny.new(:host => config(:amqp_host),
                     :port => config(:amqp_port),
                     :username => config(:amqp_username),
                     :password => config(:amqp_password))
    conn.start

    channel = conn.create_channel
    debug "Setting prefetch to #{config(:amqp_prefetch)}"
    channel.prefetch(config(:amqp_prefetch))
    debug "Connection to #{config(:amqp_host)} succeded"

    exchange = channel.topic(config(:amqp_exchange), :durable => true,
                             :auto_delete => false)

    handlers.each do |h|
      queue = channel.queue("#{h}s", {:durable => true})\
                         .bind(exchange, :routing_key => "evt.#{h}")

      info "Binding handler #{h} to routing key evt.#{h}"

      queue.subscribe(:ack => true) do |headers, properties, msg|
        start = Time.now
        begin
          data = retrieve_event(msg)
          send(h, data)

          channel.acknowledge(headers.delivery_tag, false)
          info "Success processing event. Type: #{data['type']}, ID: #{data['id']}, Time: #{Time.now.to_ms - start.to_ms} ms"
        rescue Exception => e
          # Give a message a chance to be reprocessed
          if headers.redelivered?
            warn "Error processing event. Type: #{data['type']}, ID: #{data['id']}, Time: #{Time.now.to_ms - start.to_ms} ms"
            channel.reject(headers.delivery_tag, false)
          else
            channel.reject(headers.delivery_tag, true)
          end

          STDERR.puts e
          STDERR.puts e.backtrace.join("\n")
        end
      end
    end

    stopped = false
    while not stopped
      begin
        sleep(1)
      rescue Interrupt => _
        debug 'Exit requested'
        stopped = true
      end
    end

    debug 'Closing AMQP connection'
    channel.close unless channel.nil?
    conn.close unless conn.nil?

  end

end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
