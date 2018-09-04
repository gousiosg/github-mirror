def assert_difference(command, increment = 1)
  current_count = eval(command)
  yield
  eval(command).must_equal(current_count + increment)
end

def assert_no_difference(command)
  current_count = eval(command)
  yield
  eval(command).must_equal current_count
end
