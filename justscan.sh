
#!/bin/bash
# dependency: scanimage

function show_help() {
  echo
  echo -e "USAGE: bash justscan.sh -d <OUTPUT DIRECTORY> -c <ID> \n"
  echo -e "-d : The directory you want to write to, please no trailing /, e.g. /ECSL-CDs"
  echo -e "-c : The ID of the item, e.g. callnumber, accessionID, diskID, etc. No spaces"
  echo -e "Example:\njustscan.sh -d /ECSL-CDs -c qa76.73.j38.r54.2002x will output: /ECSL-CDs/QA76-73-J38-R54-2002x.tiff"  
  echo
  exit 1
}

OPTIND=1
dir=""
dir=${dir%/}
ID=""
diskID=""

# Parse arguments
while getopts "h?d:c:" opt; do
    case "$opt" in
    h|\?)
        show_help
        ;;
    d)  dir=$OPTARG
        ;;
    c)  ID=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift
garbage="$@"

# Check all required parameters are present
if [ -z "$dir" ] || [ -z "$ID" ] || [ "$garbage" ]; then
  echo "parameters required"
  exit 1
fi

### Clean ID ###
diskID=${ID^^//./-} #make all caps and replace . with -

### Get correct scanner location ###
bus=$(lsusb | grep Epson | cut -d " " -f 2)
device=$(lsusb | grep Epson | cut -d " " -f 4 | cut -d ":" -f 1)
scanimage -L
echo "Epson scanner at Bus: $bus Device: $device"
echo "If scanner not found (no bus/device), then scanner is not available."
echo
scanner="epson2:libusb:$bus:$device"

tiff="${dir}/${diskID}.tiff"
#cropped="$dir/$diskID.tiff"

if [ -e $tiff ]; then
  echo $tiff "already exists:"
  ls -l $tiff
  read -p "Would you like to replace existing scan? [y/n] " response
  if [[ "$response" =~ ^([Nn])+$ ]]; then
    exit 
  fi
fi

mkdir -p ${dir}
scanimage --mode=Color --format=tiff --resolution 300 -x 150 -y 150 >> $tiff

if [ $tiff ]; then
  echo "scan complete"
  ls -l $tiff
else
  echo "ERROR: ${tiff} not found."
fi

### old code for cropping image to edges
#convert $tiff -crop `convert $tiff -virtual-pixel edge -blur 0x15 -fuzz 15% -trim -format '%[fx:w]x%[fx:h]+%[fx:page.x]+%[fx:page.y]' info:` +repage $cropped
#echo "image cropped"
