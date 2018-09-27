require 'yaml'
require 'tmpdir'

require 'ghtorrent/utils'

module GHTorrent
  module Settings

    include GHTorrent::Utils

    CONFIGKEYS = {
        :amqp_host => 'amqp.host',
        :amqp_port => 'amqp.port',
        :amqp_username => 'amqp.username',
        :amqp_password => 'amqp.password',
        :amqp_exchange => 'amqp.exchange',
        :amqp_prefetch  => 'amqp.prefetch',

        :sql_url => 'sql.url',

        :mirror_urlbase => 'mirror.urlbase',
        :mirror_persister => 'mirror.persister',
        :mirror_history_pages_back => 'mirror.history_pages_back',
        :user_agent => 'mirror.user_agent',
        :store_pull_request_commits => 'mirror.store_pull_request_commits',

        :github_token => 'mirror.token',

        :attach_ip => 'mirror.attach_ip',

        :rescue_loops => 'mirror.rescue_loops',
        :req_limit => 'mirror.req_limit',
        :fork_commits => 'mirror.fork_commits',
        :commit_handling => 'mirror.commit_handling',

        :logging_level => 'logging.level',
        :logging_uniq => 'logging.uniq',
        :logging_file => 'logging.file',

        :geolocation_service => 'geolocation.service',
        :geolocation_wait => 'geolocation.wait',
        :geolocation_bing_key => 'geolocation.bing_key',
        :geolocation_gmaps_key => 'geolocation.gmaps_key'
    }

    DEFAULTS = {
        :amqp_host => 'localhost',
        :amqp_port => 5672,
        :amqp_username => 'github',
        :amqp_password => 'github',
        :amqp_exchange => 'github',
        :amqp_prefetch  => 1,

        :sql_url => 'sqlite://github.db',

        :mirror_urlbase => 'https://api.github.com/',
        :mirror_persister => 'noop',
        :mirror_history_pages_back => 10,
        :user_agent => 'ghtorrent',
        :store_pull_request_commits => 'false',

        :github_token => 'place your github token here',

        :attach_ip => '0.0.0.0',

        :rescue_loops => 'true',
        :req_limit => 2,
        :fork_commits => 'fork_point',
        :commit_handling => '',

        :logging_level => 'info',
        :logging_uniq => '',
        :logging_file => 'stdout',

        :geolocation_service => 'osm',
        :geolocation_wait => '2',
        :geolocation_bing_key => '',
        :geolocation_gmaps_key => ''
    }

    def config(key, use_default = true)
      begin
        a = read_value(settings, CONFIGKEYS[key])
        if a.nil? && use_default
          DEFAULTS[key]
        else
          a
        end
      rescue StandardError => e
        if use_default
          DEFAULTS[key]
        else
          raise e
        end
      end
    end

    def merge(more_keys)
      more_keys.each {|k,v| CONFIGKEYS[k] = v}
    end

    def merge_config_values(config, values)
      values.reduce(config) {|acc, k|
        acc.merge_recursive write_value(config, CONFIGKEYS[k[0]], k[1])
      }
    end

    def override_config(config_file, setting, new_value)
      merge_config_values(config_file, {setting => new_value})
    end

    def settings
      raise StandardError.new('Unimplemented')
    end

  end
end
