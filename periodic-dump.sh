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
dateName=`date -d @$timeEnd -u +'%Y-%m-%dT%H%M%SZ'`

# _id example:
# 4f208c3e08d69a1835000077
# 000102030405060708091011
# |      ||    ||  ||    |
# time    mach  pid count

endId=`printf '%08x0000000000000000' $timeEnd`
startId=`printf '%08x0000000000000000' $timeStart`

echo "Dumping database from `date -d @$timeStart` to `date -d @$timeEnd`"

# Dump events and commits
rm -rf dump
mongodump --db github --collection events -q '{"_id" : {"$gte" : ObjectId("'$startId'"), "$lt"  : ObjectId("'$endId'")} }' || exit 1
mongodump --db github --collection commits -q '{"_id" : {"$gte" : ObjectId("'$startId'"), "$lt"  : ObjectId("'$endId'")} }' || exit 1

# Report the metadata for the given database
meta()
{
	echo -n "Number of $1: "
	mongo --quiet --eval 'db.'$1'.find({"_id" : {"$gte" : ObjectId("'$startId'"), "$lt"  : ObjectId("'$endId'")} }).count() + 0' github
	echo -n "Uncompressed size of $1: "
	wc -c dump/github/$1.bson | awk '{printf "%d bytes ", $1}'
	du -h dump/github/$1.bson | awk '{print " (" $1 ")" }'
}

(
	echo "Start date: `date -u -d @$timeStart +'%Y-%m-%dT%H:%M:%SZ'`"
	echo "End date: `date -u -d @$timeEnd +'%Y-%m-%dT%H:%M:%SZ'`"
	meta commits
	meta events
) |
tee README.$dateName.txt >dump/github/README.txt

# Create an archive of the dumped files
mv dump/github github-dump.$dateName
tar -cf - github-dump.$dateName | bzip2 -c >github-dump.$dateName.tar.bz2

# Update last run info
echo $timeEnd >lastrun
