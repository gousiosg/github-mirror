require 'test_helper'

class TestRetriever
  include GHTorrent::Utils
end

describe 'Utils' do
  let(:retriever) { TestRetriever.new }

  describe 'read_value' do
    it 'must read a nested value using 2 dot syntax' do
      hsh = { 'a' => { 'b' => { 'c' => :d } } }
      retriever.read_value(hsh, 'a.b.c').must_equal :d
    end

    it 'must read a nested value using N dot syntax' do
      hsh = { 'a' => { 'b' => { 'c' => { 'd' => { 'e' => :f } } } } }
      retriever.read_value(hsh, 'a.b.c.d').must_equal('e' => :f)
      retriever.read_value(hsh, 'a.b.c.d.e').must_equal :f
    end
  end

  describe 'write_value' do
    it 'must append or overwrite a nested key using 1 dot syntax' do
      hsh = { 'x' => { 'y' => { 'z' => :o } } }
      retriever.write_value(hsh, '', '').must_equal(hsh)

      expected_merge = { 'x' => { 'y' => { 'z' => :o, '@' => '#' } } }
      retriever.write_value(hsh, 'x.y', '@' => '#').must_equal(expected_merge)

      retriever.write_value(hsh, 'x.y', '@').must_equal('x' => { 'y' => '@' })
    end

    it 'must append or overwrite a nested key using N dot syntax' do
      hsh = { 'x' => { 'y' => { 'z' => { 'o' => { 'm' => :n } } } } }

      expected_merge = { 'x' => { 'y' => { 'z' => { 'o' => { 'm' => :n }, '@' => '#' } } } }
      retriever.write_value(hsh, 'x.y.z', '@' => '#').must_equal(expected_merge)

      expected_merge = { 'x' => { 'y' => { 'z' => { 'o' => { 'm' => :p } } } } }
      retriever.write_value(hsh, 'x.y.z.o.m', :p).must_equal(expected_merge)
    end
  end

  describe 'user_type' do
    it 'must return value based on input' do
      retriever.user_type('User').must_equal('USR')
      retriever.user_type(Faker::Name.first_name).must_equal('ORG')
    end
  end
end
