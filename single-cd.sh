#!/usr/bin/env bash
# bash
#@jesswhyte, rewrite of single-cd.sh/single-barcode.sh/single-cd-nocall.sh, from 2016

function show_help() {
	echo
	echo -e "USAGE: single-cd.sh -d /output-directory/ -l LIBRARY \n"
	echo -l ": The library or archive the collection is from."
	echo -o ": The directory you want to output to, e.g. /mnt/data/"
    echo -m ": MMSID e.g. alma991105954773306196, optional"
    echo -b ": item barcode, e.g. 31761095831004, optional"
    echo -d ": Disk ID, e.g. B2014-004-001, B2014-004-002, optional"
    echo -N ": boolean flag for multiple disks in object"
 	echo -J ": boolean flag for if object is part of a journal or series"
    echo
    echo -e "Example:\n./single-cd.sh -l ECSL -o /mnt/data/ -m alma991105954773306196"  
	echo 
}

multiple=false
journal=false
OPTIND=1
dir=""
dir=${dir%/}
lib=""
diskID=""
barcode=""
MMSID=""
drive="/dev/cdrom"

# Parse arguments
while getopts "h?o:l:m:b:d:NJ" opt; do
    case "$opt" in
    h|\?)
        show_help
	exit
        ;;
    o)  dir=$OPTARG
        ;;
    l)  lib=$OPTARG
        ;;
    m)  MMSID=$OPTARG
        ;;
    b)  barcode=$OPTARG
        ;;
    d)  diskID=$OPTARG
        ;;
    N)  multiple=true
        ;;
    J)  journal=true
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

# Check all required parameters are present
if [ -z "$lib" ]; then
  echo "Library or archive (-l) is required!"
  echo -e "Valid libraries:\n${LIBS[*]}"
  exit 
elif [ -z "$dir" ]; then
  echo "output directory (-o) is required!"
  exit 	
fi

# ask if there are multiple disks
if $multiple; then
    echo
    IFS= read -re -p 'Multiple discs: Which Disc # is this, e.g. 001, 002, 003? ' disknum
    echo
fi

#### GET diskID, the FILENAME, based on callnumber or provided diskID ###

if [[ $barcode != "" ]]; then
    bash barcode-pull.sh -b ${barcode} -f > tmp.json
    echo "Using barcode: ${barcode}"
    if $journal; then 
        echo "JOURNAL OR SERIES identified by -J. Using item_data.alternative_call_number"
        diskID=$(jq -r .item_data.alternative_call_number tmp.json)
    else
        diskID=$(jq -r .holding_data.permanent_call_number tmp.json)
    fi
    echo "callNumber=${diskID}"
elif [[ $MMSID != "" ]]; then 
    bash mmsid-pull.sh -m ${MMSID} -f > tmp.json
    echo "Using MMSID: ${MMSID}"
    diskID=$(jq -r .delivery.bestlocation.callNumber tmp.json)
    echo "callNumber=${diskID}"
elif [[ $diskID != "" ]]; then
    echo "Using: ${diskID}" # this is a placeholder
fi

#diskID="${diskID^^// /-//./-//--/-//\"}" # replace spaces, dots and double dashes with single dashes, remove double quotes
diskID=${diskID// /-}
diskID=${diskID//./-}
diskID=${diskID^^}
diskID=${diskID//--/-}
diskID=${diskID//\"/}
echo "diskID=${diskID}"

if [[ -n "$disknum" ]]; then
	diskID="${diskID}-DISK_${disknum}"
fi
	
	
echo ""
read -p "Please insert disc into drive and hit Enter"
echo
read -p "Please hit Enter again, once disc is fully LOADED"
echo

#get CD INFO
cdinfo=$(isoinfo -d -i /dev/cdrom)
volumeCD=$(echo "$cdinfo" | grep "^Volume id:" | cut -d " " -f 3)
#get blockcount/volume size of CD
blockcount=$(echo "$cdinfo" | grep "^Volume size is:" | cut -d " " -f 4)
if test "$blockcount" = ""; then
	echo
	echo FAIL: catdevice FATAL ERROR: Blank blockcount >&2
	#exit 2
fi

#get blocksize of CD
blocksize=$(echo "$cdinfo" | grep "^Logical block size is:" | cut -d " " -f 5)
if test "$blocksize" = ""; then
	echo
	echo FAIL: catdevice FATAL ERROR: Blank blocksize >&2
	#exit 2
fi

##### Display CD INFO #####
echo ""
echo "Volume label for CD is: "$volumeCD
echo "Volume size for CD is: "$blockcount
echo 
dir=${dir%/}
mkdir -p $dir

#### RIP ISO #####
echo "Ripping CD to ${dir}/${diskID}.iso"
echo
dd bs=${blocksize} count=${blockcount} if=/dev/cdrom of=${dir}/${diskID}.iso status=progress
touch ${dir}/${diskID}.iso ## for testing

##### SCANNING CD #####
echo
read -p "Do you want to scan this disc? [y/n] " response
if [[ "$response" =~ ^([Yy])+$ ]]; then
	echo "Ejecting drive..."
	eject
	read -p "Please put disc on scanner and hit any key when ready"
    bash justscan.sh -d $dir -c ${diskID}
else
    echo "skipping scanning disc"
fi

#### Pulling metadata #####
echo
read -p "Do you want to pull the catalog metadata for this disk [y/n] " metaresponse 
if [[ "${metaresponse}" =~ ^([Yy])+$ ]]; then
    if [[ $barcode != "" ]]; then
        MMSID=$(jq -r .bib_data.mms_id tmp.json)
        bash mmsid-pull.sh -m alma${MMSID} -f > tmp.json
        jq -r '.pnx | del(.delivery,.display.source,.display.crsinfo)' tmp.json > ${dir}/${diskID}.json
    elif [[ $MMSID != "" ]]; then 
        jq -r '.pnx | del(.delivery,.display.source,.display.crsinfo)' tmp.json > ${dir}/${diskID}.json
    else
        echo "no barcode or MMSID provided to pull metadata."
    fi
else
    echo "skipping metadata pull"
fi

echo
echo "Files just created in ${dir}"
find ${dir} -type f -name "${diskID}.*"
echo
if [[ $barcode != "" ]]; then
    echo "Item Barcode is: ${barcode}"
fi
echo

rm tmp.json


