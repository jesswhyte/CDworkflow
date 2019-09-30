#!/bin/bash -i
#TO DO: move scripts to path, generalize, etc

function show_help() {
	echo
	echo -e "USAGE: single-barcode.sh -d /output-directory/ -l LIBRARY \n"
	echo -l ": The library the collection is from."
	echo -d ": The directory you want to write to, e.g. /share/ECSL-ISO-AllBatches/"
 	echo -e "Example:\n./single-barcode.sh -l ECSL -d /share/ECSL-ISO-AllBatches/"  
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

function scandisk {
	tiff="$dir/$calldum/$calldum-original.tiff"
	cropped="$dir/$calldum/$calldum.tiff"
	if [ -e $cropped ]; then
		echo $cropped "exists" && echo
		ls $cropped
	fi
	echo
	read -p "Do you want to scan this disk? [y/n] " response
	echo
	if [[ "$response" =~ ^([Yy])+$ ]]; then
		echo "Ejecting drive..." && 
		eject
		echo
		read -p "Please put disk on scanner and hit any key when ready"
		echo
		echo "Scanning...: $tiff" 
		scanimage -d "$scanner" --format=tiff --mode col --resolution 300 -x 150 -y 150 >> $tiff
		convert $tiff -crop `convert $tiff -virtual-pixel edge -blur 0x15 -fuzz 15% -trim -format '%[fx:w]x%[fx:h]+%[fx:page.x]+%[fx:page.y]' info:` +repage $cropped
		echo
		echo "Scan complete and image cropped"
		echo
	fi
}

function multipledisks {
	echo
	IFS= read -re -p 'Are there multiple disks for this object? [y/n] ' multiple
	if [[ "$multiple" == "y" ]]; then
		echo
		IFS= read -re -p 'Which Disk # is this, e.g. 1, 2, 3? ' disknum
		echo
	fi
}


OPTIND=1
dir=""
lib=""
barcode=""
callnum=""
calldum=""
answer="y"
drive="/dev/cdrom"

# Parse arguments
while getopts "h?d:l:s:" opt; do
    case "$opt" in
    h|\?)
        show_help
	exit
        ;;
    d)  dir=$OPTARG
        ;;
    l)  lib=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

garbage="$@"

# Check all required parameters are present
if [ -z "$lib" ]; then
  echo "Library (-l) is required!"
  exit 
elif [ -z "$dir" ]; then
  echo "output directory (-d) is required!"
  exit 	
elif [ "$garbage" ]; then
  echo "$garbage is garbage."
  exit 
fi

# Sanity checking
LIBS=(ARCH ART ASTRO CHEM CRIM DENT OPIRG EARTH EAL ECSL FCML FNH GERSTEIN INFORUM INNIS KNOX LAW MDL MATH MC PONTIF MUSIC NEWCOLLEGE NEWMAN OISE PJRC PHYSICS REGIS RCL UTL ROM MPI STMIKES TFRBL TRIN UC UTARMS UTM UTSC VIC)
array_contains LIBS "$lib" && lv=1 || lv=0
if [ $lv -eq 0 ]; then
  echo "$lib is not a valid library name."
  echo -e "Valid libraries:\n${LIBS[*]}"
  echo
  exit 
fi

### Get correct scanner location ###
scanner="epson2:libusb:"
bus=$(lsusb | grep Epson | cut -d " " -f 2)
device=$(lsusb | grep Epson | cut -d " " -f 4 | cut -d ":" -f 1)
if [ -z "$device" ]; then 
	echo
	echo "***ERROR: SCANNER NOT FOUND***"
	exit 1
else
	scanner="epson2:libusb:$bus:$device"
fi

numResults=""

while [[ "$numResults" != "1" ]]; do
	echo 
	IFS= read -re -p 'Scan barcode: ' barcode
	echo
	calljson=$(curl --silent "https://search.library.utoronto.ca/search?N=0&Nu=p_work_normalized&Np=1&Nr=p_item_id:$barcode&format=json")
	numResults=$(echo $calljson | jq .result.numResults)
	if [ "$numResults" -eq "0" ]; then
		echo "ERROR: No catalog results found. Try using catkey with single-cd.sh"
		echo
	elif [ "$numResults" -gt "1" ]; then
		echo "ERROR: More than one catalog result found."
		echo
		IFS= read -re -i "$catkey" -p 'Enter cat key (can find by searching library.utoronto.ca) or Ctrl+C to exit: ' catkey
		echo
		calljson=$(curl -H "Accept:application/json" "https://search.library.utoronto.ca/details?$catkey&format=json")	
		title=$(echo $calljson | jq .record.title)
		if [[ -n "$title" ]]; then
			echo
			echo "TITLE FOUND: $title"
			numResults=1
		fi
	elif [ "$numResults" -eq "1" ]; then
		title=$(echo $calljson | jq .result.records[].title)
		catkey=$(echo $calljson | jq .result.records[].catkey)
		echo
		echo "SUCCESS: One cat result found: $title"
		continue
	fi
done
	
#Get call number
numItems=""
numItems=$(echo $calljson | jq '.result.records[].holdings.items | length')
if [ "$numItems" -eq "0" ]; then 
	echo
	echo "ERROR: no holdings or items found."
elif [ "$numItems" -gt "1" ]; then
	echo
	echo "More than one holding/item found."
	holdings=$(echo $calljson | jq .result.records[].holdings.items[])
	echo
	echo "$holdings"
	echo
	IFS= read -re -i "$item" -p 'Enter Item number you want (e.g. 1, 2, 3): ' item 
	item="$(($item-1))"
	callnum=$(echo $calljson | jq .result.records[].holdings.items[$item].callnumber)
elif [ "$numItems" -eq "1" ]; then
	callnum=$(echo $calljson | jq .result.records[].holdings.items[].callnumber)
fi

callnum=${callnum// /-} #remove spaces
callnum=${callnum^^} #capitalize
callnum=${callnum//./-} #replace dots with dashes
callnum=${callnum//--/-} #replace double dashes
callnum=$(sed 's/"//g' <<< $callnum)

echo
echo "callnumber is $callnum"

calldum=$callnum

multipledisks

if [[ -n "$disknum" ]]; then
	calldum="$calldum-DISK$disknum"
	echo
	echo "directory and file is $calldum"
fi
	
	
echo ""
read -p "Please insert disk into drive and hit Enter"
echo
read -p "Please hit Enter again, once disc is LOADED"
echo

#get CD INFO
cdinfo=$(isoinfo -d -i /dev/cdrom)
volumeCD=$(echo "$cdinfo" | grep "^Volume id:" | cut -d " " -f 3)
#get blockcount/volume size of CD
blockcount=$(echo "$cdinfo" | grep "^Volume size is:" | cut -d " " -f 4)
if test "$blockcount" = ""; then
	echo
	echo FAIL: catdevice FATAL ERROR: Blank blockcount >&2
	exit 2
fi

#get blocksize of CD
blocksize=$(echo "$cdinfo" | grep "^Logical block size is:" | cut -d " " -f 5)
if test "$blocksize" = ""; then
	echo
	echo FAIL: catdevice FATAL ERROR: Blank blocksize >&2
	exit 2
fi

#echo back of CD INFO
echo ""
echo "Volume label for CD is: "$volumeCD
echo "Volume size for CD is: "$blockcount
echo 
dir=${dir%/}
mkdir -p $dir/$calldum

#Rip ISO
echo "Ripping CD to $dir/$calldum/$calldum.iso"
echo
dd bs=$blocksize count=$blockcount if=/dev/cdrom of=$dir/$calldum/$calldum.iso status=progress
#touch $dir/$calldum/$calldum.iso
	
scandisk

if [[ -n "$catkey" ]]; then
	echo
	CD-catpull-barcode.py -l $lib -d $dir -c $calldum -k $catkey
else
	echo
	CD-catpull-barcode.py -l $lib -d $dir -c $calldum
fi


