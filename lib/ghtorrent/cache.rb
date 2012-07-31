require 'digest/sha1'
require 'fileutils'

require 'ghtorrent/logging'
require 'ghtorrent/settings'

module GHTorrent
  module Cache
    include GHTorrent::Logging
    include GHTorrent::Settings

    # Root dir for cached objects.
    def cache_dir
      @cache_dir ||= config(:cache_dir)
      @cache_dir
    end

    # The maximum time an item can be cached before being considered stale
    def max_life
      @max_life ||= config(:cache_stale_age)
      @max_life
    end

    # Put an object to the cache
    def cache_put(key, object)
      file = cache_location(key)
      FileUtils.mkdir_p(File.dirname (file))

      begin
        File.open(file, 'w') do |f|
          f.flocked? do
            YAML::dump object, f
          end
        end
      rescue
        warn "Could not cache object #{file} for key #{key}"
      end
    end

    # Get the object indexed by +key+ from the cache. Returns nil if the
    # key is not found or the object is too old.
    def cache_get(key)
      file = cache_location(key)

      unless File.exist?(file)
        return nil
      end

      unless (Time.now() - File.mtime(file)) < max_life
        debug "Cached object for key #{key} too old"
        return nil
      end

      begin
        File.open(file, 'r') do |f|
          f.flocked? do
            YAML::load(f)
          end
        end
      rescue
        warn "Could not read object from cache location #{file}"
        File.delete(file)
      end
    end

    private

    def cache_location(key)
      hash = hashkey(key)
      start = hash[0,2]
      File.join(cache_dir, start, hash)
    end

    def hashkey(key)
      Digest::SHA1.hexdigest key
    end

  end
end

class File
  def flocked? &block
    status = flock LOCK_EX
    case status
      when false
        return true
      when 0
        begin
          block ? block.call : false
        ensure
          flock LOCK_UN
        end
      else
        raise SystemCallError, status
    end
  end
end
