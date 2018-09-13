require 'test_helper'

describe 'Time' do
  describe 'to_ms' do
    it 'must convert time to millisecond' do
      time = Time.new(2017, 05, 01, 01, 03, 05).utc
      time.to_ms.must_equal(time.to_i * 1000)
    end
  end
end
