require 'ghtorrent/hash'

module GHTorrent
  module Utils

    def self.included(other)
      other.extend self
    end

    # Read the value for a key whose format is "foo.bar.baz" from a hierarchical
    # map, where a dot represents one level deep in the hierarchy.
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

    # Overwrite an existing +key+ whose format is "foo.bar" (where a dot
    # represents one level deep in the hierarchy) in hash +to+ with +value+.
    # If the key does not exist, it will be added at the appropriate depth level
    def write_value(to, key, value)
      return to if key.nil? or key == ""

      prev = nil
      key.split(/\./).reverse.each {|x|
        a = Hash.new
        a[x] = if prev.nil? then value else prev end
        prev = a
        a
      }

      to.merge_recursive(prev)
    end

    def user_type(type)
      if type == "User"
        "USR"
      else
        "ORG"
      end
    end
  end
end
