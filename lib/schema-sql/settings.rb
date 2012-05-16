require 'yaml'

module GHTorrent
  module Settings

    include GHTorrent::Utils

    CONFIGKEYS = {
        :amqp_host => "amqp.host",
        :amqp_port => "amqp.port",
        :amqp_user => "amqp.user",
        :amqp_passwd => "amqp.password",

        :sql_url => "sql.url",

        :mirror_urlbase => "mirror.urlbase",
        :mirror_urlbase_v2 => "mirror.urlbase.urlbase_v2",
        :mirror_reqrate => "mirror.reqrate",
        :mirror_pollevery => "mirror.pollevery",
        :mirror_persister => "mirror.persister"
    }

    def config(key)
      read_value(settings, CONFIGKEYS[key])
    end

    def merge(more_keys)
      more_keys.each {|k,v| CONFIGKEYS[k] = v}
    end

  end
end