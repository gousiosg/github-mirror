#!/usr/bin/env ruby
#
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
#``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
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

require 'trollop'

# Base class for all GHTorrent command line utilities. Provides basic command
# line argument parsing and command bootstraping support. The order of
# initialization is the following:
# prepare_options
# validate
# go
class Command

  attr_reader :args, :options

  # Specify the run method for subclasses.
  class << self
    def run(args = ARGV)
      command = new(args)
      command.process_options
      command.validate

      begin
        command.go
      rescue => e
        STDERR.puts e.message
        if command.options.verbose
          STDERR.puts e.backtrace.join("\n")
        else
          STDERR.puts e.backtrace[0]
        end
        exit 1
      end
    end
  end

  def initialize(args)
    @args = args
  end

  # Specify and parse supported command line options.
    def process_options
      command = self
      @options = Trollop::options(@args) do

        command.prepare_options(self)

        banner <<-END
Standard options:
        END

        opt :config, 'config.yaml file location', :short => 'c',
            :default => 'config.yaml'
        opt :verbose, 'verbose mode', :short => 'v'
      end

      @args = @args.dup
      ARGV.clear
    end

  # Get the version of the project
  def version
    IO.read(File.join(File.dirname(__FILE__), '..', '..', 'VERSION'))
  end

  # This method should be overriden by subclasses in order to specify,
  # using trollop, the supported command line options
  def prepare_options(options)
  end

  # Examine the validity of the provided options in the context of the
  # executed command. Subclasses can also call super to also invoke the checks
  # provided by this class.
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

  # Name of the command that is currently being executed.
  def command_name
    File.basename($0)
  end

  # The actual command code.
  def go
  end

  private

  def file_exists?(file)
    begin
      File::Stat.new(file)
      true
    rescue
      false
    end
  end

end

# vim: set sta sts=2 shiftwidth=2 sw=2 et ai :
