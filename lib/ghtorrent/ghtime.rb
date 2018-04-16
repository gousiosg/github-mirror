# renamed unit to ghtime.rb from original name of time.rb
# time.rb was trouncing on the ruby version of Time
class Time
  def to_ms
    (self.to_f * 1000.0).to_i
  end
end
