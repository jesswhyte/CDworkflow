#!/bin/bash -i
#TO DO: move scripts to path, generalize, etc

function show_help() {
	echo
	echo -e "USAGE: checknimbie-barcode.sh -s /ISO-dir/ -d /output-directory/ -l LIBRARY \n"
	echo -l ": The library the collection is from."
	echo -d ": The directory you want to write to, e.g. /share/ECSL-ISO-AllBatches/"
	echo -s ": The source directory for iso files, e.g. /share/Nimbie_ISOs"
 	echo -e "Example:\n./checknimbie-barcode.sh -l ECSL -s /share/Nimbie_ISOs/ -d /share/ECSL-ISO-AllBatches/"  
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
		echo $cropped "exists"
		ls $cropped
	fi
	read -p "Do you want to scan this disk? [y/n] " response
	if [[ "$response" =~ ^([Yy])+$ ]]; then
		echo "Ejecting drive..."
		eject
		read -p "Please put disk on scanner and hit any key when ready"
		echo "Scanning...: $tiff"
		scanimage -d "$scanner" --format=tiff --mode col --resolution 300 -x 150 -y 150 >> $tiff
		convert $tiff -crop `convert $tiff -virtual-pixel edge -blur 0x15 -fuzz 15% -trim -format '%[fx:w]x%[fx:h]+%[fx:page.x]+%[fx:page.y]' info:` +repage $cropped
		echo "Scan complete and image cropped"
	fi
}

function ddISO {
	read -p "Do you want to manually create an .ISO now (y/n)? " ddresponse && echo $ddresponse
		if [[ "$ddresponse" != "n" ]]; then 	
			#Rip ISO
			echo "Ripping CD $dir/$calldum/$calldum.iso"
			mkdir -p -m 777 $dir/$calldum
			dd bs=$blocksize count=$blockcount if=/dev/cdrom of=$dir/$calldum/$calldum.iso status=progress	
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
			mkdir -p -m 777 $dir/$calldum
			mv -iv $ISOresponse $dir/$calldum/$calldum.iso
		else			
			checkmd5
		fi
	else
		ddISO
	fi
}

function CD-catpull-barcode {
	read -p "Do you want to pull and check catalog metadata? [y/n] " catresponse && echo $catresponse
	if [[ "$catresponse" != "n" ]]; then
		if [[ -n "$catkey" ]]; then
			CD-catpull-barcode.py -l $lib -d $dir -c $calldum -k $catkey
		else
			CD-catpull-barcode.py -l $lib -d $dir -c $calldum
		fi
	else 
		echo "No metadata pulled. project log NOT updated."
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
		mkdir -p -m 777 $dir/$calldum
		mv -v $iso $dir/$calldum/$calldum.iso	
	else 
		echo "Checksums DO NOT MATCH"
		echo "you will need to manually create ISO using dd"
		ddISO
	fi
}

function doublecheck {
	read -p "Double check md5 checksums [y/n]: " md5response && echo $md5response
	if [[ "$md5response" != "y" ]]; then
		mkdir -p -m 777 $dir/$calldum
		mv -iv $iso $dir/$calldum/$calldum.iso
	else			
		checkmd5
	fi	
}

function multipledisks {
	IFS= read -re -p 'Are there multiple disks for this object? [y/n] ' multiple
	if [[ "$multiple" == "y" ]]; then
		IFS= read -re -p 'Which Disk # is this, e.g. 1, 2, 3? ' disknum
	fi
}

OPTIND=1
dir=""
lib=""
source=""
callnum=""
calldum=""
answer="y"
drive="/dev/cdrom"
barcode=""

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
    s)  source=$OPTARG
	;;	
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

dir=${dir%/}

### Get correct scanner location ###
scanner="epson2:libusb:"
bus=$(lsusb | grep Epson | cut -d " " -f 2)
device=$(lsusb | grep Epson | cut -d " " -f 4 | cut -d ":" -f 1)
if [ -z "$device" ]; then 
	echo "***ERROR: SCANNER NOT FOUND***"
	exit 1
else
	scanner="epson2:libusb:$bus:$device"
fi

### GET VOLUME NAMES OF NIMBIE ISO FILES ###
if [ -f volumeIDs-temp.txt ] ; then 
	rm volumeIDs-temp.txt
fi

numResults=""

### Work out callnum ###
numResults=""

while [[ "$numResults" != "1" ]]; do
	echo ""
	IFS= read -re -i "$barcode" -p 'Scan barcode: ' barcode
	calljson=$(curl --silent "https://search.library.utoronto.ca/search?N=0&Nu=p_work_normalized&Np=1&Nr=p_item_id:$barcode&format=json")
	numResults=$(echo $calljson | jq .result.numResults)
	if [ "$numResults" -eq "0" ]; then
		echo "ERROR: No catalog results found."
	elif [ "$numResults" -gt "1" ]; then
		echo "ERROR: More than one catalog result found."
		IFS= read -re -i "$catkey" -p 'Enter cat key (can find by searching library.utoronto.ca) or Ctrl+C to exit: ' catkey
		calljson=$(curl -H "Accept:application/json" "https://search.library.utoronto.ca/details?$catkey&format=json")	
		title=$(echo $calljson | jq .record.title)
		if [[ -n "$title" ]]; then
			echo "TITLE FOUND: $title"
			numResults=1
		fi
	elif [ "$numResults" -eq "1" ]; then
		title=$(echo $calljson | jq .result.records[].title)
		catkey=$(echo $calljson | jq .result.records[].catkey)
		echo "SUCCESS: One cat result found: $title"
		continue
	fi
done
	
#Get call number
numItems=""
numItems=$(echo $calljson | jq '.result.records[].holdings.items | length')
if [ "$numItems" -eq "0" ]; then 
	echo "ERROR: no holdings or items found."
elif [ "$numItems" -gt "1" ]; then
	echo "More than one holding/item found."
	holdings=$(echo $calljson | jq .result.records[].holdings.items[])
	echo "$holdings"
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

echo "callnumber is $callnum"

multipledisks

calldum=$callnum
if [[ -n "$disknum" ]]; then
	calldum="$calldum.DISK$disknum"
fi



### Insert Disk ###	
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
echo "Checking List of ISO's..."

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
		echo "No Volume Name for CD, but ISO Size is :"$isosize
		iso=$(echo $line | cut -d "," -f 1)
		echo "ISO is: "$iso
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
				echo "ISO is: "$iso
				doublecheck
			
			done		
		fi		
		
	else
		grep $volumeCD volumeIDs-temp.txt | while read -r line; do
			iso=$(echo $line | cut -d "," -f 1)
			echo "MATCH FOUND: "$line
			echo "Copying ISO to new location..."
			if [ -e $dir/$calldum/$calldum.iso ]; then
				echo "ISO file already exists. Not moving ISO file. Please check."
			else	
				mkdir -p -m 777 $dir/$calldum
				mv -iv $iso $dir/$calldum/$calldum.iso
			fi			
		
		done	
	fi
fi	

#scan the disk
scandisk
#pull the metadata using python script

CD-catpull-barcode

#remove old volumeIDs-temp.txt
rm volumeIDs-temp.txt



