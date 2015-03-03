require 'rubygems'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/command'
require 'ghtorrent/retriever'
require 'ghtorrent/transacted_gh_torrent'
require 'ghtorrent/commands/ght_retrieve_repo'

class GHTRetrieveUser < GHTRetrieveRepo

  def prepare_options(options)
    options.banner <<-BANNER
An efficient way to get all data for a single user

#{command_name} [options] user

    BANNER
  end

  def set_deleted(user)
    ght.transaction do
      ght.get_db.from(:users).\
       where(:login => user).\
       update(:users__deleted => true)
    end
    warn "User #{user} marked as deleted"
  end

  def validate
    super
    Trollop::die "One argument is required" unless args[0] && !args[0].empty?
  end

  def go
    self.settings = override_config(settings, :mirror_history_pages_back, -1)

    user_entry = ght.transaction{ght.ensure_user(ARGV[0], false, false)}
    on_github = api_request(ghurl ("users/#{ARGV[0]}"))

    if on_github.empty?
      if user_entry.nil?
        warn "User #{ARGV[0]} does not exist on GitHub"
        exit
      else
        set_deleted(ARGV[0])
        exit
      end
    else
      if user_entry.nil?
        warn "Error retrieving user #{ARGV[0]}"
        exit
      end
    end

    user = user_entry[:login]

    def send_message(function, user)
      begin
        ght.send(function, user)
      rescue Exception => e
        puts STDERR, e.message
        puts STDERR, e.backtrace
      end
    end

    functions = %w(ensure_user_following ensure_user_followers ensure_orgs ensure_org)

    if ARGV[1].nil?
      functions.each do |x|
        send_message(x, user)
      end
    else
      Trollop::die("Not a valid function: #{ARGV[1]}") unless functions.include? ARGV[1]
      send_message(ARGV[1], user)
    end

  end
end

class TransactedGHTorrent

  def ensure_user_followers(user)
    check_transaction do
      super(user)
    end
  end

  def ensure_orgs(user)
    check_transaction do
      super(user)
    end
  end

  def ensure_org(user, members = true)
    check_transaction do
      super(user, members)
    end
  end

end
