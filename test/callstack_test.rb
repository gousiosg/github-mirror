require "test/unit"
require 'ghtorrent'

class CallStackTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_constructor
    assert_raise Exception do
      CallStack.new('users', 0)
      CallStack.new('users', 0)
    end
  end

  def test_push
    stack = CallStack.new('users1', 0)
    assert_not_nil stack

    stack.push("foo bar")
    stack.push("2")
    stack.push("1234421")
    stack.empty
  end

  def test_pop
    stack = CallStack.new('users2', 0)
    assert_not_nil stack

    stack.push("foo bar")
    stack.push("2")
    stack.push("1234421")

    assert stack.pop == "1234421"
    stack.empty
  end

  def test_push_pop_push
    stack = CallStack.new('users3', 0)
    assert_not_nil stack

    stack.push("foo bar")
    stack.push("2")

    stack.pop

    stack.push("1234421")

    stack

    stack.empty
  end

  def test_stress
    stack = CallStack.new('users4', 0)
    1..1000.times do
      txt = (0...rand(20)).map{65.+(rand(25)).chr}.join
      stack.push txt
    end

    1..999.times do
      stack.pop
    end
    stack.pop
  end
end