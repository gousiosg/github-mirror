# Copyright 2012 Georgios Gousios <gousiosg@gmail.com>
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#   1. Redistributions of source code must retain the above
#      copyright notice, this list of conditions and the following
#      disclaimer.
#
#   2. Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials
#      provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module GHTorrent
  module Utils

    def self.included(other)
      other.extend self
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

    def user_type(type)
      if type == "User"
        "USR"
      else
        "ORG"
      end
    end
  end
end