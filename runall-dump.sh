#!/bin/sh
# Run dumps for the preceding months

rm -f lastrun
./periodic-dump.sh "2011-08-01 12:00"
./periodic-dump.sh "2011-09-01 12:00"
./periodic-dump.sh "2011-10-01 12:00"
./periodic-dump.sh "2011-11-01 12:00"
./periodic-dump.sh "2011-12-01 12:00"
./periodic-dump.sh "2012-01-01 12:00"
./periodic-dump.sh "2012-02-01 12:00"
