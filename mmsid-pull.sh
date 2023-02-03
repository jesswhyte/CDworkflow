#!/bin/bash
# catalog pulls using mmsid

function show_help() {
  echo
  echo -e "USAGE: mmsid-pull.sh -m <MMSID> "
  echo -e "-m : mmsid e.g. alma991105954773306196"
  echo -f "-f : set to receive full json record"
  echo
  exit 1
}

fulljson=false

# Parse arguments
while getopts "h?m:f" opt; do
    case "$opt" in
    h|\?)
        show_help
        ;;
    m)  MMSID=$OPTARG
        ;;
    f)  fulljson=true
        ;;
    esac
done

if [ -z "$MMSID" ]; then
    echo "-m MMSID required"
    exit 1
fi

if $fulljson; then
    curl -s "https://librarysearch.library.utoronto.ca/primaws/rest/pub/pnxs/L/${MMSID}?vid=01UTORONTO_INST:UTORONTO&lang=en" 2>/dev/null
else
# curl command to get just get relevant catalog metadata 
    curl -s "https://librarysearch.library.utoronto.ca/primaws/rest/pub/pnxs/L/${MMSID}?vid=01UTORONTO_INST:UTORONTO&lang=en" | jq -r '.pnx | del(.delivery,.display.source,.display.crsinfo)'
fi 


