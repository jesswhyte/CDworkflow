#!/bin/bash -i
#TO DO: move scripts to path, generalize, etc

function show_help() {
	echo
	echo -e "USAGE: single-cd-nocall.sh -d /output-directory/ -c COLL -t 'transcript of label' -i DiskID\n"
	echo -c ": The collection or lib the disk is from, Please No Spaces"
	echo -d ": The directory you want to write to, e.g. /share/UTARMS/"
	echo -t ": A transcript of the disk label, please avoid special characters."
	echo -i ": Disk ID, e.g. 001, 002"
 	echo -e 'Example:\n./single-cd.sh -d /share/UTARMS/ -c B2014-005 -t "Drafts -- 1987" -i 001'  
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
	tiff="$dir/$coll/$calldum/$calldum.tiff"
#	cropped="$dir/$coll/$calldum/$calldum.tiff"
	if [ -e $tiff ]; then
		echo $tiff "exists"
		ls $tiff
	fi
	read -p "Do you want to scan this disk? [y/n] " response
	if [[ "$response" =~ ^([Yy])+$ ]]; then
		echo "Ejecting drive..."
		eject
		read -p "Please put disk on scanner and hit any key when ready"
		echo "Scanning...: $tiff"
		#touch $tiff
		#touch $cropped
		scanimage -d "$scanner" --format=tiff --mode col --resolution 300 >> $tiff
		#convert $tiff -crop `convert $tiff -virtual-pixel edge -blur 0x15 -fuzz 15% -trim -format '%[fx:w]x%[fx:h]+%[fx:page.x]+%[fx:page.y]' info:` +repage $cropped
		echo "Scan complete, please manually check scans once collection is complete."
	fi
}

OPTIND=1
dir=""
coll=""
callnum=""
calldum=""
transcript=""
answer="y"
drive="/dev/cdrom"
note="NA"

# Parse arguments
while getopts "h?d:c:t:i:" opt; do
    case "$opt" in
    h|\?)
        show_help
	exit
        ;;
    d)  dir=$OPTARG
        ;;
    c)  coll=$OPTARG
        ;;
    t)  transcript=$OPTARG
    	;;
    i)  callnum=$OPTARG
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

garbage="$@"

# Check all required parameters are present
if [ -z "$coll" ]; then
  echo "Collection (-c) is required!"
  exit 1
elif [ -z "$dir" ]; then
  echo "output directory (-d) is required!"
  exit 1
elif [ -z "$callnum" ]; then
  echo "disk id (-i) is required!"
  exit 1
elif [ "$garbage" ]; then
  echo "$garbage is garbage."
fi

### Get correct scanner location ###
scanner="epson2:libusb:"
bus=$(lsusb | grep Epson | cut -d " " -f 2)
device=$(lsusb | grep Epson | cut -d " " -f 4 | cut -d ":" -f 1)
if [ -z "$device" ]; then 
	echo "***ERROR: SCANNER NOT FOUND***"
	echo "script will not run, turn on scanner"
	exit 1
else
	scanner="epson2:libusb:$bus:$device"
fi

callnum=${callnum^^}
calldum=${callnum//./-}
	
	
echo ""
read -p "Please insert CD into drive and hit Enter"
read -p "Please hit Enter again, once CD is LOADED"

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

mkdir -p $dir/$coll/$calldum

ddir=$dir/$coll/$calldum

#Rip ISO
echo "Ripping CD $dir/$coll/$calldum/$calldum.iso"
dd bs=$blocksize count=$blockcount if=/dev/cdrom of=$ddir/$calldum.iso status=progress
#touch $dir/$coll/$calldum/$calldum.iso
	
scandisk

##NOTE UPDATE
IFS= read -re -i "$note" -p 'Update CD notes, otherwise hit Enter: ' note

if test -f "$dir/$coll/$calldum/$calldum.iso"; then
	echo -e "\"$coll\",\"$calldum\",\"CD\",\"$transcript\",\"$note\",\"ISO=OK\"" >> $dir/$coll/projectlog.csv
else
	echo -e "\"$coll\",\"$calldum\",\"CD\",\"$transcript\",\"$note\",\"ISO=NO\"" >> $dir/$coll/projectlog.csv
fi

echo -e "CD imaged as: \nCollection: $coll \nDiskID: $calldum \nFormat: CD \nTranscript: $transcript \nNotes: $note"
echo "Information recorded in project log at: $dir/$coll/projectlog.csv" 
echo "Thank you!"


