module GHTorrent
  module Commands
    # Defines a process to download the full data available for a single user
    module FullUserRetriever

      include GHTorrent::Geolocator

      def persister
        ght.persister
      end

      def settings
        raise "Unimplemented"
      end

      def ght
        @ghtorrent ||= get_mirror_class.new(settings)
        @ghtorrent
      end

      def update_persister(login, new_user)
        r = persister.del(:users, {'login' => login})
        persister.store(:users, new_user)

        if r > 0
          debug "Persister entry for user #{login} updated, #{r} records removed"
        else
          debug "Added persister entry from user #{login}"
        end
      end

      def retrieve_user(login)
        debug "User #{login} update started"
        user_entry = ght.transaction { ght.ensure_user(login, false, false) }
        on_github = api_request(ghurl ("users/#{login}"))

        if (not on_github.nil?) and on_github.empty?
          if user_entry.nil?
            warn "User #{login} does not exist on GitHub"
            return
          else
            ght.transaction do
              ght.db.from(:users).where(:login => login).update(:users__deleted => true)
            end
            warn "User #{login} marked as deleted"
            return
          end
        else
          if user_entry.nil?
            warn "Error retrieving user #{login}"
            return
          end
        end

        # Refresh the persister with the latest info from GitHub
        unless on_github.empty?
          update_persister(login, on_github)
        end

        # Update geo location information
        geo = geolocate(location: on_github['location'])

        ght.db.from(:users).where(:login => login).update(
          # Geolocation info
          :users__long         => geo['long'].to_f,
          :users__lat          => geo['lat'].to_f,
          :users__country_code => geo['country_code'],
          :users__state        => geo['state'],
          :users__city         => geo['city'],
          :users__location     => on_github['location'],

          # user details
          :users__name         => on_github['name'],
          :users__company      => on_github['company'],
          :users__email        => on_github['email'],
          :users__deleted      => false,
          :users__fake         => false
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

        info "User #{login} updated"
      end
    end
  end
 end
