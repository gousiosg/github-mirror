require 'rubygems'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/retriever'
require 'ghtorrent/transacted_ghtorrent'
require 'ghtorrent/commands/ght_retrieve_repo'

class GHTRetrieveUser < GHTRetrieveRepo

  def prepare_options(options)
    options.banner <<-BANNER
An efficient way to get all data for a single user

#{command_name} [options] user

    BANNER
  end

  def validate
    super
    Trollop::die "One argument is required" unless args[0] && !args[0].empty?
  end

  def go
    self.settings = override_config(settings, :mirror_history_pages_back, -1)
    user_entry = ght.transaction{ght.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{ARGV[0]}"
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

    functions = %w(ensure_user_followers ensure_orgs ensure_org)

    if ARGV[2].nil?
      functions.each do |x|
        send_message(x, user)
      end
    else
      Trollop::die("Not a valid function: #{ARGV[2]}") unless functions.include? ARGV[2]
      send_message(ARGV[2], user)
    end

  end
end

class TransactedGhtorrent 

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
