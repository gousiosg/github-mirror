#!/bin/sh
#
# Create the periodic database dump files
#

# Directory where the script must run
RUNDIR=/home/dds/src/github-mirror

# Time to start dumping from
if [ -r lastrun ]
then
	timeStart=`cat lastrun`
else
	timeStart=0
fi

# Time to end dumping
if [ "$1" = "" ]
then
	timeEnd=`date +%s`
else
	timeEnd=`date -d "$1" +%s` || exit 1
fi

# Name used for the files
dateName=`date -d @$timeEnd -u +'%Y-%m-%d'`

# _id example:
# 4f208c3e08d69a1835000077
# 000102030405060708091011
# |      ||    ||  ||    |
# time    mach  pid count

endId=`printf '%08x0000000000000000' $timeEnd`
startId=`printf '%08x0000000000000000' $timeStart`

echo "Dumping database from `date -d @$timeStart` to `date -d @$timeEnd`"

collections=`echo "show collections"|mongo --quiet github|egrep -v "system|bye"`
	
rm -rf dump
for col in $collections; do

	echo "Dumping $col"
	mongodump --db github --collection $col -q '{"_id" : {"$gte" : ObjectId("'$startId'"), "$lt"  : ObjectId("'$endId'")} }' || exit 1
done

# Report the metadata for the given database
meta()
{
	echo -n "Number of $1: "
	mongo --quiet --eval 'db.'$1'.find({"_id" : {"$gte" : ObjectId("'$startId'"), "$lt"  : ObjectId("'$endId'")} }).count() + 0' github
	echo -n "Uncompressed size of $1: "
	wc -c dump/github/$1.bson | awk '{printf "%d bytes ", $1}'
	du -h dump/github/$1.bson | awk '{print " (" $1 ")" }'
}

for col in $collections; do
(
	echo "Start date: `date -u -d @$timeStart +'%Y-%m-%dT%H:%M:%SZ'`"
	echo "End date: `date -u -d @$timeEnd +'%Y-%m-%dT%H:%M:%SZ'`"
	meta $col 
) 
done |
tee README.$dateName.txt >dump/github/README.txt || exit 1

# Create an archive of the dumped files
mv dump/github github-dump.$dateName || exit 1
if ! tar -cf - github-dump.$dateName | bzip2 -c >github-dump.$dateName.tar.bz2 
then
	rm -f github-dump.$dateName.tar.bz2 README.$dateName.txt
	exit 1
fi

# Create a .torrent file. Requires installed bittornado 
btmakemetafile http://www.sumotracker.com/announce github-dump.$dateName.tar.bz2 --target github-dump.$dateName.torrent --announce_list "http://www.sumotracker.com/announce|udp://tracker.openbittorrent.com:80|http://tracker.prq.to/announce|udp://tracker.publicbt.com:80/announce"

# Update last run info
echo $timeEnd >lastrun || exit 1

# Clean up
rm -rf github-dump.$dateName dump
