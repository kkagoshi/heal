#
#	Usage:	buildcmd <gluster-volume-heal-VOL-info>
#
#	Build a script to run on an RHGS server node. 
#	Script is executes getfattr and stat command against all path and gfid.
#	An input file is sosreport/sos_command/gluster/gluster_volume_<VOLUME>_info, not
#	"gluster volume info" which contains all RHGS vols.
#
#
[ $# != 1 ] || \
[ ! -f $1 ] && { echo "Usage: xxxx <heal info file>" ; exit 1; }

info=$1
wrkdir=${HOME}/healdir
out1=${wrkdir}/files

[ ! -d ${wrkdir} ] &&  mkdir -p ${wrkdir} && chmod 755 ${wrkdir}
[ ! -d ${wrkdir} ] && { echo "ERR: failed to mkdir ${wrkdir}"; exit 1; }

rm -f ${out1}

sed -e '/^Brick/d' -e '/^Number/d' -e '/^Status/d' -e '/^$/d' $info  | sort | uniq |\
awk '
/^<gfid:/ {
	#print $0;
	gfid=substr($0,7); sub(/>/,"", gfid);
	printf("/.glusterfs/%s/%s/%s\n", substr(gfid, 1, 2), substr(gfid, 3, 2), gfid);
	}
/^\// {
	print $1;
}
' > ${out1}


for brick in `awk '/^Brick/ {print $2;}' info`
do
	node=`echo $brick | sed 's;:.*$;;'`
	brickpath=`echo $brick | sed 's;^.*:;;'`
	echo "## brick:$brick node:$node  brickpah:$brickpath"
	nodesh=${wrkdir}/${node}.sh

	cat ${out1} | while read file
	do
		dotglusterfs=`echo $file | cut -f 1 -d '/'`
		if [ "${dotglusterfs}" == ".glusterfs" ] ; then
			ftype="GFID"
		else
			ftype="FILE"
		fi
		echo "#"; echo "# $file"; echo "#"
		echo "echo \"#\""; echo "echo \"# $ftype - $file\""; echo "echo \"#\""
		echo "getfattr -m . -d -e hex ${brickpath}${file}"
		echo "echo \"#\""
		echo "stat ${brickpath}${file}"
		echo "echo"
	done > ${nodesh}
	chmod 755 ${nodesh}
done
