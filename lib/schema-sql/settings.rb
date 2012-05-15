require 'yaml'

module GHTorrent
  module Settings

    CONFIGKEYS = {
        :amqp_host => "amqp.host",
        :amqp_port => "amqp.port",
        :amqp_user => "amqp.user",
        :amqp_passwd => "amqp.password",

        :mirror_urlbase => "mirror.urlbase",
        :mirror_urlbase_v2 => "mirror.urlbase.urlbase_v2"
    }

    #yaml = YAML::load_file @configuration

    def self.config(key)
      read_value(yaml, key)
    end

    # Read a value whose format is "foo.bar.baz" from a hierarchical map
    # (the result of a JSON parse or a Mongo query), where a dot represents
    # one level deep in the result hierarchy.
    def read_value(from, key)
      return from if key.nil? or key == ""

      key.split(/\./).reduce({}) do |acc, x|
        unless acc.nil?
          if acc.empty?
            # Initial run
            acc = from[x]
          else
            if acc.has_key?(x)
              acc = acc[x]
            else
              # Some intermediate key does not exist
              return nil
            end
          end
        else
          # Some intermediate key returned a null value
          # This indicates a malformed entry
          return nil
        end
      end
    end
  end
end