module GHTorrent
  module Commands
    # Defines a process to download the full data available for a single user
    module FullUserRetriever

      include GHTorrent::Geolocator

      def ght
        raise 'Unimplemented'
      end

      def persister
        ght.persister
      end

      def retrieve_user(login)
        self.settings = override_config(settings, :mirror_history_pages_back, 1000)
        user_entry = ght.transaction { ght.ensure_user(login, false, false) }
        on_github = api_request(ghurl ("users/#{login}"))

        if on_github.empty?
          if user_entry.nil?
            warn "User #{login} does not exist on GitHub"
            exit
          else
            ght.transaction do
              ght.get_db.from(:users).where(:login => login).update(:users__deleted => true)
            end
            warn "User #{login} marked as deleted"
            return
          end
        else
          if user_entry.nil?
            warn "Error retrieving user #{login}"
            exit
          end
        end

        # Update geo location information
        geo = geolocate(on_github['location'])

        ght.get_db.from(:users).where(:login => login).update(
            :users__long => geo[:long],
            :users__lat => geo[:lat],
            :users__country_code => geo[:country_code],
            :users__state => geo[:state],
            :users__city => geo[:city],
        )

        user = user_entry[:login]
        def send_message(function, user)
          begin
            ght.send(function, user)
          rescue StandardError => e
            puts STDERR, e.message
            puts STDERR, e.backtrace
          end
        end

        functions = %w(ensure_user_following ensure_user_followers ensure_orgs ensure_org)

        functions.each do |x|
          send_message(x, user)
        end

      end
    end
  end
 end