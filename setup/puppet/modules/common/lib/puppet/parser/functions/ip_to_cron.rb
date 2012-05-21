# Downloaded from http://reductivelabs.com/trac/puppet/wiki/Recipes/cron
#
# provides a "random" value to cron based on the last bit of the machine IP address.
# used to avoid starting a certain cron job at the same time on all servers.
# if used with no parameters, it will return a single value between 0-59
# first argument is the occournce within a timeframe, for example if you want it to run 2 times per hour
# the second argument is the timeframe, by default its 60 minutes, but it could also be 24 hours etc
#
# example usage
# ip_to_cron()     - returns one value between 0..59
# ip_to_cron(2)    - returns an array of two values between 0..59
# ip_to_cron(2,24) - returns an array of two values between 0..23
require 'ipaddr'
module Puppet::Parser::Functions
	newfunction(:ip_to_cron, :type => :rvalue) do |args|
		occours = (args[0] || 1).to_i	
		scope   = (args[1] || 60).to_i
		ip      = IPAddr.new(lookupvar('ipaddress')).to_s.split('.')[3].to_i
		base    = ip % scope
		if occours == 1
			base
		else
			cron = Array.new
			(1..occours).each do |i|
				cron << ((base - (scope / occours * i)) % scope)
			end
			return cron.sort
		end
	end
end
