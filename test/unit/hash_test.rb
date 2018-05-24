require 'test_helper'

describe Hash do
  let(:hash1) { { key1: 1 } }
  let(:hash2) { { key1: 2 } }
  let(:hash3) { { key1: { test: 1 } } }
  let(:hash4) { { key1: { test: 2 } } }

  it 'should overwrite the hash value' do
    assert_equal ({ key1: 2 }), hash1.merge_recursive(hash2)
  end

  it 'should not overwrite the hash value' do
    refute_equal ({ key1: 2 }), hash1.merge_recursive(hash2, false)
    assert_equal ({ key1: [1, 2] }), hash1.merge_recursive(hash2, false)
  end

  it 'should overwrite the value of hash of hash' do
    assert_equal ({ key1: { test: 2 } }), hash3.merge_recursive(hash4)
    assert_equal ({ key1: { test: 2 } }), hash3.merge_recursive(hash4, false)
  end
end
