#!/bin/sh
# Can specify the following flags
# --debug to obtain verbose output
# --graph --debug --graphdir /tmp  to create dot dependency graphs

case "$1" in
retrieval)
	shift
	puppet apply $* /usr/share/puppet/manifests/retrieval.pp
	;;
mirror)
	shift
	puppet apply $* /usr/share/puppet/manifests/mirror.pp
	;;
*)
	echo "usage: $0 mirror|retrieval [--debug] [--graph] [--graphdir d]" 1>&2
	exit 1
esac
