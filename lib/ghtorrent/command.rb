require 'rubygems'
require 'trollop'

class Command

  attr_reader :args, :options

  class << self
    def run(args = ARGV)
      command = new(args)
      command.process_options
      command.validate

      begin
        command.go
      rescue => e
        STDERR.puts e.message
        STDERR.puts e.backtrace.join("\n") if command.options.verbose
        exit 1
      end
    end
  end

  def initialize(args)
    @args = args
  end

  def version
    IO.read(File.join(File.dirname(__FILE__), '..', '..', 'VERSION'))
  end

  def process_options
    command = self
    @options = Trollop::options(@args) do

      #version(command.version)
      command.prepare_options(self)

      banner <<-END
Standard options:
      END

      opt :config, 'config.yaml file location', :short => 'C', :default => 'config.yaml'
      opt :verbose, 'verbose mode', :short => 'v'
    end

    @args = @args.dup
    ARGV.clear
  end

  def prepare_options(options)
  end

  def validate
    if options[:config].nil?
      unless (file_exists?("config.yaml") or file_exists?("/etc/ghtorrent/config.yaml"))
        Trollop::die "No config file in default locations (., /etc/ghtorrent)
                      you need to specify the #{:config} parameter. Read the
                      documnetation on how to create a config.yaml file."
      end
    else
      Trollop::die "Cannot find file #{options[:config]}" unless file_exists?(options[:config])
    end
  end

  def command_name
    File.basename($0)
  end

  def go

  end

  private

  def file_exists?(file)
    begin
      File::Stat.new("config.yaml")
      true
    rescue
      false
    end
  end
end
