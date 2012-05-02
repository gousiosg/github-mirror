#!/bin/sh
#
# Create the periodic database dump files
#

# Directory to place compressed files and torrents
OUTDIR=/home/data/github-mirror/dumps

# Base URL for HTTP dir containing torrents and data 
WEBSEED=http://ikaria.dmst.aueb.gr/ghtorrent/

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

# Do the same per collection
for col in $collections; do
	echo "Archiving $col.bson"
	if [ ! -s dump/github/$col.bson ]; then
		echo "Collection empty, skipping"
		continue
	fi

	if ! tar zcf $OUTDIR/$col-dump.$dateName.tar.gz dump/github/$col.bson
	then
		rm -f $OUTDIR/$col-dump.$dateName.tar.gz
		exit 1
	fi

	mktorrent -a udp://tracker.openbittorrent.com:80 -a udp://tracker.publicbt.com:80/announce -a http://tracker.bittorrent.am/announce -w $WEBSEED/$col-dump.$dateName.tar.gz -o $OUTDIR/$col-dump.$dateName.torrent $OUTDIR/$col-dump.$dateName.tar.gz
done

# Update last run info
echo $timeEnd >lastrun || exit 1

# Clean up
rm -rf dump 

