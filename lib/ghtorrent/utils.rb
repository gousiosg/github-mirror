module GHTorrent
  module Utils
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