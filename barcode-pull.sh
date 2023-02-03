#!/bin/bash
# catalog pulls using barcode

function show_help() {
  echo
  echo -e "USAGE: barcode-pull.sh -b <BARCODE> \n"
  echo -e "-b : barcode"
  echo -f "-f : set to receive full json record"
  echo -e "Example:\n barcode-pull.sh -b 31761095831004"  
  echo
  exit 1
}

fulljson=false

# Parse arguments
while getopts "h?b:f" opt; do
    case "$opt" in
    h|\?)
        show_help
        ;;
    b)  barcode=$OPTARG
        ;;
    f)  fulljson=true
        ;;
    esac
done

if [ -z "$barcode" ]; then
    IFS= read -re -p 'Scan barcode: ' barcode
fi

if [ -z "$catAPIkey" ]; then
    read -re -p 'Enter catalog API key: ' catAPIkey
    echo "consider setting your catalog API key as an environment variable, e.g. export catAPIkey=_______"
    echo 
fi

if $fulljson; then
    curl -s -L -X GET "https://api-ca.hosted.exlibrisgroup.com/almaws/v1/items?item_barcode=${barcode}&apikey=${catAPIkey}" -H "accept: application/json" 2>/dev/null
else
# curl command to get just biblio catalog metadata 
    curl -s -L -X GET "https://api-ca.hosted.exlibrisgroup.com/almaws/v1/items?item_barcode=${barcode}&apikey=${catAPIkey}" -H "accept: application/json" 2>/dev/null | jq ".bib_data" 
fi 
