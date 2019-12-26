#!/usr/bin/env bash

usage()
{
cat <<EOF 1>&2
Usage: $0 [command] <args>

Dispatch to a GHTorrent data retrieval operation 

[command] can be one of: events, data-retrival, load
<args> are passed verbatim to the dispatched program
EOF
}

cmd=""
case $1 in
	events)
		cmd="/usr/local/bin/ruby -I/ghtorrent/lib/ /ghtorrent/bin/ght-mirror-events"	
		;;
	data-retrieval)
		cmd="/usr/local/bin/ruby -I/ghtorrent/lib/ /ghtorrent/bin/ght-data-retrieval"	
		;;
	load)
		cmd="/usr/local/bin/ruby -I/ghtorrent/lib/ /ghtorrent/bin/ght-load"	
		;;
	*)
		usage
		;;
esac

shift

$cmd $@
