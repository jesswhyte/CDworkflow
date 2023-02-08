#!/bin/bash -i
#TO DO: inventory of disks

function show_help() {
	echo
	echo -e "reads a barcode and then outputs catalog information to a designated csv"
	echo -e "relies on barcode-pull.sh, also in this repository"
	echo -e "requires catAPIkey to be set"
	echo -e "USAGE: inventory.sh -o /output-directory/filename.csv"
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


OPTIND=1
barcode=""
diskID=""


# Parse arguments
while getopts "h?o:" opt; do
    case "$opt" in
    h|\?)
        show_help
	exit
        ;;
    o)  outCSV=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

garbage="$@"

# Check all required parameters are present
if [ -z "$outCSV" ]; then
  echo "output directory (-o) is required!"
elif [ "$garbage" ]; then
  echo "$garbage is garbage."
fi

another="y"
while [[ "$another" == "y" ]]; do
	IFS= read -re -p 'Scan barcode: ' barcode
	bash barcode-pull.sh -b ${barcode} -f > tmp.json
	#echo "Using barcode: ${barcode}"
	diskID=$(jq -r .holding_data.permanent_call_number tmp.json)
	MMSID=$(jq -r .bib_data.mms_id tmp.json)
	title=$(jq .bib_data.title tmp.json)

	#diskID="${diskID^^// /-//./-//--/-//\"}" # replace spaces, dots and double dashes with single dashes, remove double quotes
	diskID=${diskID// /-}
	diskID=${diskID//./-}
	diskID=${diskID^^}
	diskID=${diskID//--/-}
	diskID=${diskID//\"/}
	echo "$diskID, $title, alma$MMSID, $date"
	echo "$diskID,$title,alma$MMSID,$date" >> $outCSV
	rm tmp.json
done



