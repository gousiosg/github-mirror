#!/bin/bash
#
#

ts=`date +'%s'`
cp log.txt log-$ts
cat log.txt|grep Igno |cut -f2,3,4 -d' '|sort|uniq > toadd.txt
cat log.txt |grep Cann|cut -f3,4,5 -d' '|sort|uniq >>toadd.txt
ruby add_to_queue.rb toadd.txt
mv toadd.txt toadd-$ts
gzip log-$ts
gzip toadd-$ts
#echo > log.txt

