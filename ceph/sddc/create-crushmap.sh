#!/bin/bash
# ident: create-crushmap.sh, ver 0.1, 2017/11/23. (C)2017,Red Hat Inc.,mmuench@redhat.com
#
# DESCRIPTION:
#	reads a file with decompiled ceph crushmap and creates a new crushmap with 2 DCs and 2 storage classes

if [ $# -ne 2 ]; then
	echo "usage: $0 decomiled_crushmap_file outfile"
	exit 1
fi

INFILE=$1
OUTFILE=$2
if [ -d $INFILE ]; then
	echo "$0 FATAL 10: infile $INFILE is a directory."
	exit 1
elif [ ! -r $INFILE ]; then
	echo "$0 - FATAL 15: $INFILE is not readable or doesn't exist."
	exit 1
fi
if [ -d $OUTFILE ]; then
	echo "$0 FATAL 20: outfile $OUTFILE is a directory."
	exit 1
elif [ -f $OUTFILE ]; then
	echo "$0 FATAL 30: outfile $OUTFILE exists."
	exit 1
fi

HOSTS=
BUCKETID=100

# header is the first part of the file that we usually don't touch (except for straw algorithm version)
#   The header area ends on '# buckets' line.
HEADER_END=

if [ "XX`grep -w buckets $INFILE`" = "XX" ]; then
	echo "$0 - FATAL 100: cannot find buckets line - probably wrong file contents"
	exit 1
	
else
	HEADER_END=`grep -n "^# buckets" $INFILE|cut -d: -f1`
fi
# write header into output file and replace straw_calc_version 1 with 2
head -$HEADER_END $INFILE |sed 's/straw_calc_version 1/straw_calc_version 2/' >>$OUTFILE

# find host names
HOSTS_DC1=`grep "^host" $INFILE|awk '{print $2}'|sort -u|head -2`
if [ `grep -n "^host" $INFILE|cut -d: -f2|sort -u|wc -l` -eq 4 ]; then
	# 4 hosts defined
	HOSTS_DC2=`grep "^host" $INFILE| awk '{print $2}'|sort -u|head -4|tail -2`
elif [ `grep -n "^host" $INFILE|cut -d: -f2|sort -u|wc -l` -eq 5 ]; then
	# 5 hosts defined
	HOSTS_DC2=`grep "^host" $INFILE| awk '{print $2}'|sort -u|head -5|tail -3`
else
	echo "$0 - FATAL 40: no rule to work with other than 4 or 5 hosts defined."
	exit 3
fi

HOSTS=`grep -n "^host" $INFILE| tr ':' ' '| awk '{print $1":"$3}'`
HOSTSEND=`grep -n ^'}' $INFILE| cut -d: -f1`
for HOSTSLINE in `echo $HOSTS`; do
	HOSTNAME=`echo $HOSTSLINE|cut -d: -f2|awk '{print $1}'`
	HOSTSTART=`echo $HOSTS|cut -d: -f1`
	# find end of host definition
	HOSTEND=0
	for HEND in `echo $HOSTSEND`; do
		if [ $HEND -gt $HOSTSTART ]; then
			HOSTEND=$HEND
			break
		fi
	done
	if [ $HOSTEND -eq 0 ]; then
		echo "$0 - FATAL 110: didn't find end of $HOSTNAME definition"
		exit 1
	fi

	# we know start and end of host definition - now, get the while block, parse for osd numbers and collect them in order of weight
	DIST=`expr $HOSTEND - $HOSTSTART`
	# get osd weight first - this is our indicator on the size - we need to group osds of the same size
#	WEIGHTS=`grep -A $DIST "^host" $INFILE|grep item|awk '{print $4}'|sort -u -n|tr -d '.'`
	WEIGHTS=`grep -A $DIST "^host" $INFILE|grep item|awk '{print $4}'|sort -u -n`
	if [ `echo $WEIGHTS|tr ' ' '\n'|wc -l` -ne 2 ]; then
		echo "$0 - FATAL 120: expecting only two weights for osds but got: $WEIGHTS"
		exit 2
	fi

	# we can now savely assume that the first value is the smaller one and the second is the bigger one (in numeric order)
	SIZE1=99999
	SIZE2=99999
	for i in `echo $WEIGHTS`; do
		if [ "$SIZE1" = "99999" ]; then
			SIZE1=$i
		else
			SIZE2=$i
		fi
	done

	SLOW=
	FAST=
	if [ "$SIZE1" != "99999" -a "$SIZE2" != "99999" ]; then
		# bigger number = more capacity => slow
		FASTOSD=`grep -A $DIST "^host $HOSTNAME " $INFILE|grep item|grep -w $SIZE1| awk '{print $2}'`
		SLOWOSD=`grep -A $DIST "^host $HOSTNAME " $INFILE|grep item|grep -w $SIZE2| awk '{print $2}'`
	else
		echo "$0 - FATAL 130: didn't find the osd weights and associated osds"
		exit 2
	fi

	# create new host defintions
	# First, the "slow"
	echo 'host '$HOSTNAME'-slow {' >>$OUTFILE
	echo "        id -"$BUCKETID >>$OUTFILE
	echo "        alg straw" >>$OUTFILE
	echo "        hash 0 # rjenkins1" >>$OUTFILE
	# add now the osds
	for OSD in `echo $SLOWOSD`; do
		echo "        item $OSD weight $SIZE2" >>$OUTFILE
	done
	echo '}' >>$OUTFILE
	BUCKETID=`expr $BUCKETID + 1`

	# Second, the "fast"
	echo 'host '$HOSTNAME'-fast {' >>$OUTFILE
	echo "        id -"$BUCKETID >>$OUTFILE
	echo "        alg straw" >>$OUTFILE
	echo "        hash 0 # rjenkins1" >>$OUTFILE
	# add now the osds
	for OSD in `echo $FASTOSD`; do
		echo "        item $OSD weight $SIZE1" >>$OUTFILE
	done
	echo '}' >>$OUTFILE
	BUCKETID=`expr $BUCKETID + 1`
	# host definition finished
		
done
# all host definitions written
	

# Create now the DC definitions:
# First, DC 1 slow:
echo "datacenter ceph_slow_dc01 "'{' >>$OUTFILE
echo "        id -"$BUCKETID >>$OUTFILE
echo "        alg straw" >>$OUTFILE
echo "        hash 0" >>$OUTFILE
for DCHOST in `echo $HOSTS_DC1`; do
	echo "        item ${DCHOST}-slow weight 0.25" >>$OUTFILE
done
echo '}' >>$OUTFILE
BUCKETID=`expr $BUCKETID + 1`

# Second, DC 1 fast:
echo "datacenter ceph_fast_dc01 "'{' >>$OUTFILE
echo "        id -"$BUCKETID >>$OUTFILE
echo "        alg straw" >>$OUTFILE
echo "        hash 0" >>$OUTFILE
for DCHOST in `echo $HOSTS_DC1`; do
	echo "        item ${DCHOST}-fast weight 0.25" >>$OUTFILE
done
echo '}' >>$OUTFILE
BUCKETID=`expr $BUCKETID + 1`

# Third, DC 2 slow:
echo "datacenter ceph_slow_dc02 "'{' >>$OUTFILE
echo "        id -"$BUCKETID >>$OUTFILE
echo "        alg straw" >>$OUTFILE
echo "        hash 0" >>$OUTFILE
for DCHOST in `echo $HOSTS_DC2`; do
	echo "        item ${DCHOST}-slow weight 0.25" >>$OUTFILE
done
echo '}' >>$OUTFILE
BUCKETID=`expr $BUCKETID + 1`

# Forth, DC 2 fast:
echo "datacenter ceph_fast_dc02 "'{' >>$OUTFILE
echo "        id -"$BUCKETID >>$OUTFILE
echo "        alg straw" >>$OUTFILE
echo "        hash 0" >>$OUTFILE
for DCHOST in `echo $HOSTS_DC2`; do
	echo "        item ${DCHOST}-fast weight 0.25" >>$OUTFILE
done
echo '}' >>$OUTFILE
BUCKETID=`expr $BUCKETID + 1`

# DC defintions done.

# Create root for slow :
echo "root slow "'{' >>$OUTFILE
echo "        id -"$BUCKETID >>$OUTFILE
echo "        alg straw" >>$OUTFILE
echo "        hash 0" >>$OUTFILE
echo "        item ceph_slow_dc01 weight 0.5" >>$OUTFILE
echo "        item ceph_slow_dc02 weight 0.5" >>$OUTFILE
echo '}' >>$OUTFILE
BUCKETID=`expr $BUCKETID + 1`

# Create root for fast :
echo "root fast "'{' >>$OUTFILE
echo "        id -"$BUCKETID >>$OUTFILE
echo "        alg straw" >>$OUTFILE
echo "        hash 0" >>$OUTFILE
echo "        item ceph_fast_dc01 weight 0.5" >>$OUTFILE
echo "        item ceph_fast_dc02 weight 0.5" >>$OUTFILE
echo '}' >>$OUTFILE
BUCKETID=`expr $BUCKETID + 1`

# Create root for default : (always exists after deployment for base pools and therefor needed)
echo "root default "'{' >>$OUTFILE
echo "        id -"$BUCKETID >>$OUTFILE
echo "        alg straw" >>$OUTFILE
echo "        hash 0" >>$OUTFILE
for DCHOST in `echo $HOSTS_DC1`; do
	echo "        item ${DCHOST}-slow weight 0.25" >>$OUTFILE
done
for DCHOST in `echo $HOSTS_DC2`; do
	echo "        item ${DCHOST}-slow weight 0.25" >>$OUTFILE
done
echo '}' >>$OUTFILE
BUCKETID=`expr $BUCKETID + 1`


# root definitions done.

# Create ruleset definitions:
echo 'rule replicated_ruleset_slow {
        ruleset 1
        type replicated
        min_size 2
        max_size 10
        step take fast
        step choose firstn 2 type datacenter
        step chooseleaf firstn 0 type host
        step emit
}
rule replicated_ruleset_fast {
        ruleset 2
        type replicated
        min_size 2
        max_size 10
        step take slow
        step choose firstn 2 type datacenter
        step chooseleaf firstn 0 type host
        step emit
}
rule replicated_ruleset {
        ruleset 0
        type replicated
        min_size 1
        max_size 10
        step take default
        step chooseleaf firstn 0 type host
        step emit
}' >>$OUTFILE

echo "# end crush map" >>$OUTFILE
#Done.
