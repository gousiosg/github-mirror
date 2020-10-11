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
        @ghtorrent ||= TransactedGHTorrent.new(settings)
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

        if on_github.empty?
          if user_entry.nil?
            warn "User #{login} does not exist on GitHub"
            return
          else
            ght.transaction do
              ght.db.from(:users).where(:login => login).update(Sequel.qualify('users', 'deleted') => true)
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
        debug "Geolocation for user: #{login} returned #{geo}"

        ght.db.from(:users).where(:login => login).update(
            # Geolocation info
            Sequel.qualify('users', 'long')         => geo[:long].to_f,
            Sequel.qualify('users', 'lat')          => geo[:lat].to_f,
            Sequel.qualify('users', 'country_code') => geo[:country_code],
            Sequel.qualify('users', 'state')        => geo[:state],
            Sequel.qualify('users', 'city')         => geo[:city],
            Sequel.qualify('users', 'location')     => on_github['location'],

            # user details
            Sequel.qualify('users', 'name')    => on_github['name'],
            Sequel.qualify('users', 'company') => on_github['company'],
            Sequel.qualify('users', 'email')   => on_github['email'],
            Sequel.qualify('users', 'deleted') => false,
            Sequel.qualify('users', 'fake')    => false,
            Sequel.qualify('users', 'type')    => user_type(on_github['type']),

            # update timestamp
            Sequel.qualify('users', 'updated_at') => date(Time.now)
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

      def date(arg)
        if arg.class != Time
          time_non_zero(Time.parse(arg))
        else
          time_non_zero(arg)
        end
      end

      def time_non_zero(t)
        if t.to_i <= 0
          Time.parse('1970-01-02')
        else
          t
        end
      end

    end
  end
 end
