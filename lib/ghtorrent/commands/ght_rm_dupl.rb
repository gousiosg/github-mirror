require 'rubygems'
require 'mongo'

require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/persister'

class GHRMDupl < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Persister

  def col_info()
    {
        :commits => {
            :unq => "sha",
            :col => persister.get_underlying_connection.collection(:commits.to_s),
        },
        :events => {
            :unq => "id",
            :col => persister.get_underlying_connection.collection(:events.to_s),
        }
    }
  end

  def persister
    @persister ||= connect(:mongo, @settings)
    @persister
  end

  def prepare_options(options)
    options.banner <<-BANNER
Removes duplicate entries from collections (currently, commits and events)

#{command_name} [options] collection

#{command_name} options:
    BANNER

    options.opt :earliest, 'Seconds since epoch of earliest item to load',
                :short => 'e', :default => 0, :type => :int
    options.opt :snapshot, 'Perform clean up every x records',
                :short => 's', :default => -1, :type => :int
  end

  def validate
    super
    Trollop::die "no collection specified" unless args[0] && !args[0].empty?
  end

  # Print MongoDB remove statements that
  # remove all but one entries for each commit.
  def remove_duplicates(data, col)
    removed = 0
    data.select { |k, v| v.size > 1 }.each do |k, v|
      v.slice(0..(v.size - 2)).map do |x|
        removed += 1 if delete_by_id col, x
      end
    end
    removed
  end

  def delete_by_id(col, id)
    begin
      col.remove({'_id' => id})
      true
    rescue Mongo::OperationFailure
      puts "Cannot remove record with id #{id} from #{col.name}"
      false
    end
  end

  def go
    collection = case ARGV[0]
                   when "commits" then
                     :commits
                   when "events" then
                     :events
                   else
                     puts "Not a known collection name: #{ARGV[0]}\n"
                 end

    from = {'_id' => {'$gte' => BSON::ObjectId.from_time(Time.at(options[:earliest]))}}

    snapshot = options[:snapshot]

    puts "Deleting duplicates from collection #{collection}"
    puts "Deleting duplicates after #{Time.at(options[:earliest])}"
    puts "Perform clean up every #{snapshot} records"

    # Various counters to report stats
    processed = total_processed = removed = 0

    data = Hash.new

    # The following code needs to save intermediate results to cope
    # with large datasets
    col_info[collection][:col].find(from, :fields => col_info[collection][:unq]).each do |r|
      _id = r["_id"]
      commit = read_value(r, col_info[collection][:unq])

      # If entries cannot be parsed, remove them
      if commit.empty?
        puts "Deleting unknown entry #{_id}"
        removed += 1 if delete_by_id col_info[collection][:col], _id
      else
        data[commit] = [] if data[commit].nil?
        data[commit] << _id
      end

      processed += 1
      total_processed += 1

      print "\rProcessed #{processed} records"

      # Calculate duplicates, save intermediate result
      if snapshot > 0 and processed > snapshot
        puts "\nLoaded #{data.size} values, cleaning"
        removed += remove_duplicates data, col_info[collection][:col]
        data = Hash.new
        processed = 0
      end
    end

    removed += remove_duplicates data, col_info[collection][:col]

    puts "\nProcessed #{total_processed}, deleted #{removed} duplicates"
  end
end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
