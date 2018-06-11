require 'test_helper'

class TestPersister
  include GHTorrent::Persister
end

describe 'Persister' do
  let(:persister) { TestPersister.new }

  it 'should return an instance of persister' do
    persister.connect('noop', config)
    persister.class.must_equal TestPersister
  end

  it 'should raise error' do
    -> { persister.disconnect }.must_raise(NameError)
  end
end
