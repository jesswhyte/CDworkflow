#!/bin/bash -i
#TO DO: inventory of disks

function show_help() {
	echo
	echo -e "USAGE: inventory.sh -d /output-directory/filename.csv"
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
callnum=""
calldum=""
numResults=""

# Parse arguments
while getopts "h?d:s:" opt; do
    case "$opt" in
    h|\?)
        show_help
	exit
        ;;
    d)  outCSV=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

garbage="$@"

# Check all required parameters are present
if [ -z "$outCSV" ]; then
  echo "output directory (-d) is required!"
elif [ "$garbage" ]; then
  echo "$garbage is garbage."
fi

another="y"
while [[ "$another" == "y" ]]; do
	IFS= read -re -p 'Scan barcode: ' barcode
	calljson=$(curl --silent "https://search.library.utoronto.ca/search?N=0&Nu=p_work_normalized&Np=1&Nr=p_item_id:$barcode&format=json")
	numResults=$(echo $calljson | jq .result.numResults)
	echo "numResults are: " $numResults
	if [ "$numResults" -eq "0" ]; then
		echo "ERROR: No catalog results found."
	elif [ "$numResults" -gt "1" ]; then
		echo "ERROR: More than one catalog result found."
		IFS= read -re -i "$catkey" -p 'Enter cat key (can find by searching library.utoronto.ca) or Ctrl+C to exit: ' catkey
		calljson=$(curl -H "Accept:application/json" "https://search.library.utoronto.ca/details?$catkey&format=json")	
		title=$(echo $calljson | jq .record.title)
		if [[ -n "$title" ]]; then
			echo "TITLE FOUND: $title"
		fi
	elif [ "$numResults" -eq "1" ]; then
		title=$(echo $calljson | jq .result.records[].title)
		catkey=$(echo $calljson | jq .result.records[].catkey)
		#echo "SUCCESS: One cat result found: $title"
	fi
	
	#Get call number
	numItems=""
	numItems=$(echo $calljson | jq '.result.records[].holdings.items | length')
	if [ "$numItems" -eq "0" ]; then 
		echo "ERROR: no holdings or items found."
	elif [ "$numItems" -gt "0" ]; then
		callnum=$(echo $calljson | jq .result.records[].holdings.items[0].callnumber)
	fi

	callnum=${callnum// /-} #remove spaces
	callnum=${callnum^^} #capitalize
	callnum=${callnum//./-} #replace dots with dashes
	callnum=${callnum//--/-} #replace double dashes
	callnum=$(sed 's/"//g' <<< $callnum)
	date=`date +%Y-%m-%d`

	echo "$catkey $title $callnum $date"

	echo "$catkey,$title,$callnum,$date" >> $outCSV
done


