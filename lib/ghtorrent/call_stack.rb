module GHTorrent
  class CallStack

    @@callstacks = Hash.new

    attr_reader :name

    def self.new(*args)
      name = args[0]
      if @@callstacks.has_key? name
        @@callstacks[name]
      else
        o = allocate
        if o.__send__(:initialize, *args)
          @@callstacks[name] = o
          o
        else
          nil
        end
      end
    end

    def initialize(name, sync_every = 5)

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
              @stack.each { |l| @file.write("#{l} \n") }
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
        @@callstacks.delete[@name]
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
      @stack.delete_if { |x| true }
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
end