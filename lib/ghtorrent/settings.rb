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
        :uniq_id => 'mirror.uniq_id',
        :user_agent => 'mirror.user_agent',

        :github_username => 'mirror.username',
        :github_passwd => 'mirror.passwd',
        :github_token => 'mirror.token',

        :attach_ip => 'mirror.attach_ip',

        :rescue_loops => 'mirror.rescue_loops',
        :req_limit => 'mirror.req_limit'
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
        :mirror_history_pages_back => 1,
        :uniq_id => 'ext_ref_id',
        :user_agent => 'ghtorrent',

        :github_username => 'foo',
        :github_passwd => 'bar',
        :github_token => '',

        :attach_ip => '0.0.0.0',

        :rescue_loops => 'true',
        :req_limit => 4998
    }

    def config(key, use_default = true)
      begin
        a = read_value(settings, CONFIGKEYS[key])
        if a.nil? && use_default
          DEFAULTS[key]
        else
          a
        end
      rescue Exception => e
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
      raise Exception.new('Unimplemented')
    end

  end
end
