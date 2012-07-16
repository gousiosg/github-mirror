require 'yaml'

module GHTorrent
  module Settings

    include GHTorrent::Utils

    CONFIGKEYS = {
        :amqp_host => "amqp.host",
        :amqp_port => "amqp.port",
        :amqp_username => "amqp.username",
        :amqp_password => "amqp.password",
        :amqp_exchange => "amqp.exchange",

        :sql_url => "sql.url",

        :mirror_urlbase => "mirror.urlbase",
        :mirror_urlbase_v2 => "mirror.urlbase_v2",
        :mirror_reqrate => "mirror.reqrate",
        :mirror_pollevery => "mirror.pollevery",
        :mirror_persister => "mirror.persister",
        :mirror_commit_pages_new_repo => "mirror.commit_pages_new_repo",

        :uniq_id => "mirror.uniq_id"
    }

    def config(key)
      read_value(settings, CONFIGKEYS[key])
    end

    def merge(more_keys)
      more_keys.each {|k,v| CONFIGKEYS[k] = v}
    end

  end
end