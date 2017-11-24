#!/bin/bash
#ident: correct-crushmap.sh, ver 0.1, 2017/11/23. (C)2017,Red Hat Inc.,mmuench@redhat.com
# NEEDS: create-crushmap.sh
CMDPATH=`pwd`

COMPILED_OUT=/tmp/compiled_out.$$
DECOMPILED_OUT=/tmp/decompiled_out.$$
DECOMPILED_IN=/tmp/decompiled_in.$$
COMPILED_IN=/tmp/compiled_in.$$

if [ -d $COMPILED_OUT -o -d $COMPILED_IN -o -d $DECOMPILED_OUT -o -d $DECOMPILED_IN ]; then
	echo "$0 - FATAL 1: one of the specified filenames to use is a directory"
	exit 1
fi
if [ -f $COMPILED_OUT -o -f $COMPILED_IN -o -f $DECOMPILED_OUT -o -f $DECOMPILED_IN ]; then
	echo "$0 - FATAL 5: one of the specified filenames already exist"
	exit 1
fi

if [ ! -x create-crushmap.sh ]; then
	echo "$0 - FATAL 10: need create-crushmap.sh in local path with executable rights."
	exit 1
fi

# check whether we are root
if [ `id|awk '{print $1}'|cut -d= -f2|cut -d'(' -f1` -ne 0 ]; then
	echo "$0 - FATAL 20: need to be root on host to execute ceph command"
	exit 2
fi

ceph  -s 2>/dev/null >/dev/null
if [ $? -ne 0 ]; then
	echo "$0 - ERROR 30: unable to use ceph command"
	exit 3
fi


# set tunables
ceph osd crush tunables optimal
if [ $? -ne 0 ]; then
	echo "$0 - ERROR 40: failed to apply optimal tunings"
	exit 2
else
	echo "WAITING 20 seconds ..."
	sleep 20
fi

# get crushmap
ceph osd getcrushmap -o $COMPILED_OUT
if [ $? -ne 0 ]; then
	echo "$0 - ERROR 50: failed to get crushmap"
	exit 2
fi

# transfer into readable
crushtool -d $COMPILED_OUT -o $DECOMPILED_OUT
if [ $? -ne 0 ]; then
	echo "$0 - ERROR 60: failed to generate human readable form of crushmap"
	exit 2
fi

# create new crushmap from existing
$CMDPATH/create-crushmap.sh $DECOMPILED_OUT $DECOMPILED_IN
if [ $? -ne 0 ]; then
	echo "$0 - ERROR 70: failed to create new 2 DC crushmap from file $DECOMPILED_OUT."
	exit 2
fi

# compile new crushmap
crushtool -c $DECOMPILED_IN -o $COMPILED_IN
if [ $? -ne 0 ]; then
	echo "$0 - ERROR 80: failed to compile crushmap"
	exit 2
fi

# check crushmap
crushtool -i $COMPILED_IN --test 2>/dev/null >/dev/null
if [ $? -ne 0 ]; then
	echo "$0 - ERROR 90: failed to test crushmap successfully"
	exit 2
fi

# insert new crushmap
ceph osd setcrushmap -i $COMPILED_IN
if [ $? -ne 0 ]; then
	echo "$0 - ERROR 100: failed inject new crushmap"
	exit 2
fi

# Now, everything is (mostly) done. Wait for cluster to stable.
echo "================================================================"
echo "NEW crushmap inserted - now WAIT UNTIL cluster is HEALTHY again."
echo ""
echo "    Stop output of 'ceph -w' command with ^C."
echo "================================================================"
echo ""
echo ""
sleep 10
ceph -w
