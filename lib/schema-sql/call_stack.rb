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



class CallStack

  @@filenames = Array.new

  attr_reader :stack

  def initialize(name, sync_every = 5)
    raise Exception.new("stack for #{name} exists") if @@filenames.include? name
    @@filenames << name

    @stack = Array.new
    @name = name
    @sync = sync_every

    if File.exists?(name)
      @file = File.new(name, "r")
      puts "File #{name} exists, importing stack..."
      read = @file.readlines.reverse.reduce(0) { |acc, x|
        @stack.push x
        acc
      }
      puts "\n#{read} entries read"
      @file.close
    end

    flusher = Thread.new {
      while true
        begin
          if not @stack.empty?
            @file = File.new(name, "w+")
            @stack.each{|l| @file.write("#{l} \n")}
            @file.fsync
            @file.close
          end
          sleep(@sync)
        rescue
          puts "flusher thread failed for #{name}"
        end
      end
    }

    ObjectSpace.define_finalizer(self, proc {
      puts "Finalizer: Cleaning up #{@name}"
      @@filenames.delete_if{|x| x == @name}
      flusher.stop
      cleanup
    })

    at_exit { cleanup }

  end

  def push(item)
    @stack.push(item)
  end

  def pop()
    @stack.pop
  end

  def empty
    @stack.delete_if{|x| true}
  end

  private

  def cleanup
    if @stack.empty?
      if File.exists? @name
        puts "removing stack #{@name}"
        File.delete(@name)
      end
    else
      puts "stack #{@name} contains #{@stack.size} items"
    end
  end
end