require 'yaml'
require 'tmpdir'

require 'ghtorrent/utils'

module GHTorrent
  module Settings

    include GHTorrent::Utils

    CONFIGKEYS = {
        :amqp_host => "amqp.host",
        :amqp_port => "amqp.port",
        :amqp_username => "amqp.username",
        :amqp_password => "amqp.password",
        :amqp_exchange => "amqp.exchange",
        :amqp_prefetch  => "amqp.prefetch",

        :sql_url => "sql.url",

        :mirror_urlbase => "mirror.urlbase",
        :mirror_pollevery => "mirror.pollevery",
        :mirror_persister => "mirror.persister",
        :mirror_commit_pages_new_repo => "mirror.commit_pages_new_repo",
        :mirror_history_pages_back => "mirror.history_pages_back",
        :uniq_id => "mirror.uniq_id",
        :user_agent => "mirror.user_agent",

        :cache_mode      => "mirror.cache_mode",
        :cache_dir       => "mirror.cache_dir",
        :cache_stale_age => "mirror.cache_stale_age",

        :github_username => "mirror.username",
        :github_passwd => "mirror.passwd",

        :respect_api_ratelimit => "mirror.respect_api_ratelimit",

        :attach_ip => "mirror.attach_ip"
    }

    DEFAULTS = {
        :amqp_host => "localhost",
        :amqp_port => 5672,
        :amqp_username => "github",
        :amqp_password => "github",
        :amqp_exchange => "github",
        :amqp_prefetch  => 1,

        :sql_url => "sqlite://github.db",

        :mirror_urlbase => "https://api.github.com/",
        :mirror_pollevery => "mirror.pollevery",
        :mirror_persister => "noop",
        :mirror_commit_pages_new_repo => 3,
        :mirror_history_pages_back => 1,
        :uniq_id => "ext_ref_id",
        :user_agent => "ghtorrent",

        :cache_mode      => "dev",
        :cache_dir       => Dir::tmpdir + File::SEPARATOR + "ghtorrent",
        :cache_stale_age => 604800,

        :github_username => "foo",
        :github_passwd => "bar",

        :respect_api_ratelimit => "true",

        :attach_ip => "0.0.0.0"
    }

    def config(key, use_default = true)
      begin
        read_value(settings, CONFIGKEYS[key])
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

    def merge_config_values(values)
      values.reduce(settings) {|acc, k|
        acc.merge_recursive write_value(settings, CONFIGKEYS[k[0]], k[1])
      }
    end

    def settings
      raise Exception.new("Unimplemented")
    end

  end
end
