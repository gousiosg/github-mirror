class Schema::SchemaBase

  attr_reader :timestamp

    def initialize(timestamp = Time.now.to_i)
      @timestamp = timestamp
    end
end