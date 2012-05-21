#!/bin/sh

if [ "$0" != "tools/setup.sh" ]
then
	echo "This command can only be run as tools/setup.sh" 1>&2
	exit 1
fi

# Setup puppet to pull its files from this directory
#FILEDIR=/etc/puppet
FILEDIR=/usr/share/puppet

rm -rf $FILEDIR/manifests
rm -rf $FILEDIR/modules

mkdir -p $FILEDIR

ln -s `pwd`/manifests $FILEDIR/manifests
ln -s `pwd`/modules $FILEDIR/modules
