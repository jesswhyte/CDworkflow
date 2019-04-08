#!/bin/bash

function show_help() {
	echo
	echo -e "USAGE: bash justscan.sh -d /OUTPUT-DIR -c CALLNUM \n"
	echo -e "-d : The directory you want to write to, e.g. /ECSL-batch8/"
	echo -e "-c : The call number of the item"
 	echo -e "Example:\njustscan.sh -l ECSL -d /ECSL-batch8/ -c qa76.73.j38.r54.2002x"  
}


OPTIND=1
dir=""
callnum=""
calldum=""


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

# Parse arguments
while getopts "h?d:l:c:" opt; do
    case "$opt" in
    h|\?)
        show_help
        ;;
    d)  dir=$OPTARG
        ;;
    c)  callnum=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

garbage="$@"

# Check all required parameters are present
if [ -z "$dir" ]; then
  echo "directory (-d) is required!"
elif [ -z "$callnum" ]; then
  echo "callnumber (-c) is required!"
elif [ "$garbage" ]; then
  echo "$garbage is garbage."
fi




### Work out callnum ###
calldum1=${callnum^^}
calldum=${calldum1//./-}
echo "using callNum: $calldum"

### Get correct scanner location ###
scanner="epson2:libusb:"
bus=$(lsusb | grep Epson | cut -d " " -f 2)
device=$(lsusb | grep Epson | cut -d " " -f 4 | cut -d ":" -f 1)
echo "found Epson scanner at Bus: $bus Device: $device"
scanner="epson2:libusb:$bus:$device"

tiff="$dir$calldum/$calldum-original.tiff"
	cropped="$dir$calldum/$calldum.tiff"
	if [ -e $cropped ]; then
		echo $cropped "exists"
		ls $cropped
	fi
	echo "about to scan: $tiff"
	read -p "Do you want to scan this disk? [y/n] " response
	if [[ "$response" =~ ^([Yy])+$ ]]; then
		mkdir $dir$calldum/
		#scanner="epson2:libusb:002:004"
		read -p "Please put disk on scanner and hit any key when ready"
		scanimage -d "$scanner" --format=tiff --mode col --resolution 300 -x 150 -y 150 >> $tiff
		echo "disk tiff scan complete"
		convert $tiff -crop `convert $tiff -virtual-pixel edge -blur 0x15 -fuzz 15% -trim -format '%[fx:w]x%[fx:h]+%[fx:page.x]+%[fx:page.y]' info:` +repage $cropped
		echo "image cropped"
	fi
