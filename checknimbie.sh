#!/bin/bash -i

function show_help() {
	echo
	echo -e "USAGE: checknimbie.sh -s /ISO-dir/ -d /output-directory/ -l LIBRARY \n"
	echo -l ": The library the collection is from."
	echo -d ": The directory you want to write to, e.g. /share/ECSL-ISO-AllBatches/"
	echo -s ": The source directory for iso files, e.g. /share/Nimbie_ISOs"
	echo -b ": item barcode, e.g. 31761095831004, optional"
	echo -m ": MMSID e.g. alma991105954773306196, optional"
	echo -d ": Set Disk ID, e.g. B2014-004-001, B2014-004-002, optional"
	echo -J ": boolean flag for if object is part of a journal or series"
	echo -N ": boolean flag for multiple disks in object"
	echo
 	echo -e "Example:\n./checknimbie.sh -l ECSL -s /share/Nimbie_ISOs/ -d /share/ECSL-ISO-AllBatches/"  
	echo
}


function array_contains() {
  local array="$1[@]"
  local seeking=$2
  local in=1
  for element in "${!array}"; do
    if [[ $element == $seeking ]]; then
      in=0
      break
    fi
  done
  return $in
}


function ddISO {
	read -p "Do you want to manually create an .ISO now (y/n)? " ddresponse && echo $ddresponse
		if [[ "$ddresponse" != "n" ]]; then 	
			#Rip ISO
			echo "Ripping CD $dir/$diskID.iso"
			dd bs=$blocksize count=$blockcount if=/dev/cdrom of=$dir/$diskID.iso status=progress	
		else	
			exit 1
		fi
}

function manualISO {
	ISOresponse=""
	IFS= read -re -i "$ISOresponse" -p 'Enter a specific ISO file location if known (enter n if not known): ' ISOresponse
	if [[ "$ISOresponse" != "n" ]]; then
		read -p "Do you want to double-check the md5 checksums [y/n]: " md5response && echo $md5response
		if [[ "$md5response" != "y" ]]; then
			mv -iv $ISOresponse $dir/$diskID.iso
		else			
			checkmd5
		fi
	else
		ddISO
	fi
}

function checkmd5 {
	echo "Checking md5sum of ISO..." $iso
	md5iso=$(md5 $iso | md5sum | cut -d " " -f1)
	echo "ISO MD5 is: "$md5iso
	echo "Checking md5sum of CD..."
	md5cd=$(dd if=/dev/cdrom bs=$blocksize count=$blockcount | md5sum | cut -d " " -f1)
	echo "CD MD5 is: "$md5cd
	if [ "$md5cd" == "$md5iso" ]; then
		echo "Checksums MATCH...moving file"
		mv -v $iso $dir/$diskID.iso	
	else 
		echo "Checksums DO NOT MATCH"
		echo "you will need to manually create ISO using dd"
		ddISO
	fi
}

function doublecheck {
	read -p "Double check md5 checksums [y/n]: " md5response && echo $md5response
	if [[ "$md5response" != "y" ]]; then
		#mkdir -p -m 777 $dir/$diskID
		mv -iv $iso $dir/$diskID.iso
	else			
		checkmd5
	fi	
}

multiple=false
journal=false
OPTIND=1
dir=""
dir=${dir%/}
lib=""
source=""
diskID=""
answer="y"
barcode=""
MMSID=""
drive="/dev/cdrom"

# Parse arguments
while getopts "h?d:l:s:m:b:d:NJ" opt; do
    case "$opt" in
    h|\?)
        show_help
	exit
        ;;
    d)  dir=$OPTARG
        ;;
    l)  lib=$OPTARG
        ;;
    s)  source=$OPTARG
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

garbage="$@"

# Check all required parameters are present
if [ -z "$lib" ]; then
  echo "Library (-l) is required!"
elif [ -z "$dir" ]; then
  echo "output directory (-d) is required!"
elif [ -z "$source" ]; then
  echo "source (-s) is required!"
elif [ "$garbage" ]; then
  echo "$garbage is garbage."
fi

# Sanity checking
LIBS=(ARCH ART ASTRO CHEM CRIM DENT OPIRG EARTH EAL ECSL FCML FNH GERSTEIN INFORUM INNIS KNOX LAW MDL MATH MC PONTIF MUSIC NEWCOLLEGE NEWMAN OISE PJRC PHYSICS REGIS RCL UTL ROM MPI STMIKES TFRBL TRIN UC UTARMS UTM UTSC VIC)
array_contains LIBS "$lib" && lv=1 || lv=0
if [ $lv -eq 0 ]; then
  echo "$lib is not a valid library name."
  echo -e "Valid libraries:\n${LIBS[*]}"
fi

### GET VOLUME NAMES OF NIMBIE ISO FILES ###
if [ -f volumeIDs-temp.txt ] ; then 
	rm volumeIDs-temp.txt
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
        echo "JOURNAL OR SERIES identified by -J. Using item_data.alternative_call_number to find the Call Number"
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
	

### Insert Disk ###
echo	
read -p "Please insert disk into drive and hit Enter"
read -p "Please hit Enter again, once disc is LOADED"

# get CD INFO
cdinfo=$(isoinfo -d -i /dev/cdrom)
volumeCD=$(echo "$cdinfo" | grep "^Volume id:" | cut -d " " -f 3)

#get blockcount/volume size of CD
blockcount=$(echo "$cdinfo" | grep "^Volume size is:" | cut -d " " -f 4)
if test "$blockcount" = ""; then
	echo catdevice FATAL ERROR: Blank blockcount >&2
	exit
fi

#get blocksize of CD
blocksize=$(echo "$cdinfo" | grep "^Logical block size is:" | cut -d " " -f 5)
if test "$blocksize" = ""; then
	echo catdevice FATAL ERROR: Blank blocksize >&2
	exit
fi

#echo back CD INFO
echo ""
echo "Volume label for CD is: "$volumeCD
echo "Volume size for CD is: "$blockcount
echo ""


#Check against ISO
echo "Checking List of Nimbie ISO's to find a match..."
echo

#Load info on existing iso's (from Nimbie)
exec 2>/dev/null #outputs iso offset warnings (all output) to /dev/null
for iso in $(find $source -name "*.iso" -o -name "*.ISO" -type f); do
	#echo "checking: "$iso in $source
	isoID=$(isoinfo -d -i $iso | grep "^Volume id:" | cut -d " " -f 3) 
	isoBC=$(isoinfo -d -i $iso | grep "^Volume size is:" | cut -d " " -f 4)
	echo $iso,$isoID,$isoBC >> volumeIDs-temp.txt
done	
exec 2>/dev/tty #returns outputs to terminal

#Check if there's a match
if [ -z "$volumeCD" ]; then
	grep $blockcount volumeIDs-temp.txt | while read -r line;  do
		isosize=$(echo $line | cut -d "," -f 3)
		echo "No Volume Name for CD, but checking for matches based on ISO Size:"$isosize
		iso=$(echo $line | cut -d "," -f 1)
		echo "Match found. ISO is: "$iso
		echo
		doublecheck
	done
			
else		
	count=$(grep -c $volumeCD volumeIDs-temp.txt)
	if (( $count == 0 )) ; then
		echo "no results found on volume name..."
		manualISO
	
	elif (( $count > 1 )) ; then #tip: use (()) when comparing #'s
		echo "more than one volume name match found..."	
		grep $volumeCD volumeIDs-temp.txt
		echo "checking size..."
		bcount=$(grep -c $blockcount volumeIDs-temp.txt)
		if (( $bcount > 1 )) ; then 
			echo "more than one size result found.."
			manualISO
		
		else
			grep $blockcount volumeIDs-temp.txt | while read -r line;  do
				isosize=$(echo $line | cut -d "," -f 3)
				echo "ISO Size is :"$isosize
				iso=$(echo $line | cut -d "," -f 1)
				echo "Match found. ISO is: "$iso
				echo
				doublecheck
			
			done		
		fi		
		
	else
		grep $volumeCD volumeIDs-temp.txt | while read -r line; do
			iso=$(echo $line | cut -d "," -f 1)
			echo "MATCH FOUND: "$line
			echo "Copying ISO to new location..."
			if [ -e $dir/$diskID.iso ]; then
				echo "ISO file already exists. Not moving ISO file. Please doublecheck."
				echo
			else	
				mv -iv $iso $dir/$diskID.iso
			fi			
		
		done	
	fi
fi	

#scan the disk
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
echo "${dir} listing:"
ls -lh ${dir}
echo

rm tmp.json

#remove old volumeIDs-temp.txt
rm volumeIDs-temp.txt



