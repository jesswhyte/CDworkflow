#!/bin/bash -i
#TO DO: move scripts to path, generalize, etc

function show_help() {
	echo
	echo -e "USAGE: single-cd.sh -d /output-directory/ -l LIBRARY \n"
	echo -l ": The library the collection is from."
	echo -d ": The directory you want to write to, e.g. /share/ECSL-ISO-AllBatches/"
 	echo -e "Example:\n./single-cd.sh -l ECSL -d /share/ECSL-ISO-AllBatches/"  
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
	tiff="$dir$calldum/$calldum-original.tiff"
	cropped="$dir$calldum/$calldum.tiff"
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

OPTIND=1
dir=""
lib=""
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
elif [ -z "$dir" ]; then
  echo "output directory (-d) is required!"
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

numResults=""

while [[ "$numResults" != "1" ]]; do
	echo ""
	IFS= read -re -i "$callnum" -p 'Enter Call Number (use "."), lower-case OK: ' callnum
	#echo -n 'Enter Call Number (use "."), lower-case OK: '
	#read callnum
	callnum=${callnum^^}
	calldum=${callnum//./-}
	callnum=$(sed -e 's/\.DIS..//g' <<< $callnum)
	echo ""
	echo "Making catalog call on:  $callnum"
	calljson=$(curl -H "Accept:application/json" "https://search.library.utoronto.ca/search?N=0&Ntx=mode+matchallpartial&Nu=p_work_normalized&Np=1&Ntk=p_call_num_949&format=json&Ntt=$callnum")
	numResults=$(echo $calljson | jq .result.numResults)
	echo ""
	if [ "$numResults" -eq "0" ]; then
		echo "ERROR: No catalog results found."
	elif [ "$numResults" -gt "1" ]; then
		echo "ERROR: More than one catalog result found."
		IFS= read -re -i "$catkey" -p 'Enter cat key (can find in library catalog) or Ctrl+C to exit: ' catkey
		calljson=$(curl -H "Accept:application/json" "https://search.library.utoronto.ca/details?$catkey&format=json")	
		title=$(echo $calljson | jq .record.title)
		if [[ -n "$title" ]]; then
			echo "TITLE FOUND: $title"
			numResults=1
		fi
	elif [ "$numResults" -eq "1" ]; then
		title=$(echo $calljson | jq .result.records[].title)
		echo "SUCCESS: One cat result found: $title"
		continue
	fi
done
	
echo ""
read -p "Please insert disk into drive and hit Enter"
read -p "Please hit Enter again, once disc is LOADED"

#get CD INFO
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

#echo back of CD INFO
echo ""
echo "Volume label for CD is: "$volumeCD
echo "Volume size for CD is: "$blockcount
echo ""

mkdir -p -m 777 $dir/$calldum

#Rip ISO
echo "Ripping CD $dir/$calldum/$calldum.iso"
dd bs=$blocksize count=$blockcount if=/dev/cdrom of=$dir/$calldum/$calldum.iso status=progress
#touch $dir/$calldum/$calldum.iso
	
scandisk

if [[ -n "$catkey" ]]; then
	CD-catpull.py -l $lib -d $dir -c $callnum -k $catkey
else
	CD-catpull.py -l $lib -d $dir -c $callnum
fi


