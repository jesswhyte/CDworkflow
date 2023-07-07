#!/usr/bin/env bash

# bash
#@jesswhyte, rewrite of single-cd.sh/single-barcode.sh/single-cd-nocall.sh, from 2016
#@kenlhlui, added the support of audio discs imaging by using abcde package in June 2023

function show_help() {
	echo
	echo -e "USAGE: single-cd.sh -d /output-directory/ -l LIBRARY \n"
	echo -l ": The library or archive the collection is from."
	echo -o ": The directory you want to output to, e.g. /mnt/data/"
    echo -m ": MMSID e.g. alma991105954773306196, optional"
    echo -b ": item barcode, e.g. 31761095831004, optional"
    echo -d ": Disc ID, e.g. B2014-004-001, B2014-004-002, optional"
    echo -N ": boolean flag for multiple disks in object"
 	echo -J ": boolean flag for if object is part of a journal or series"
    echo -R ": Disc Drive path. Built-in drive = /dev/sr0, USB drive(s) = /dev/sr1(..2..), optional"
    echo -Y ": Process imgaging, scanning and pulling metadata without extra confirmation"
    echo
    echo -e "Example:\n./single-cd.sh -l ECSL -o /mnt/data/ -m alma991105954773306196"  
	echo 
}

audio=false
multiple=false
journal=false
OPTIND=1
dir=""
dir=${dir%/}
lib=""
diskID=""
barcode=""
MMSID=""
start_datetime=$(date +"%Y%m%d%H%M%S")
#random_num=$((1 + RANDOM % 100000000))
fullsteps=false

# Parse arguments
while getopts "h?D:o:l:m:b:d:NJ:Y" opt; do
    case "$opt" in
    h|\?)
        show_help
	    exit
        ;;
    o)  dir=$OPTARG
        ;;
    l)  lib=$OPTARG
        ;;
    m)  MMSID=$OPTARG
        ;;
    b)  barcode=$OPTARG
        ;;
    d)  diskID=$OPTARG
        ;;
    D)  drive=$OPTARG
        ;;
    N)  multiple=true
        ;;
    J)  journal=true
        ;;
    Y)  fullsteps=true
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

# Check all required parameters are present
if [ -z "$lib" ]; then
  echo "Library or archive (-l) is required!"
  echo -e "Valid libraries:\n${LIBS[*]}"
  exit 
elif [ -z "$dir" ]; then
  echo "output directory (-o) is required!"
  exit 	
fi

# Ask if there are multiple disks
if $multiple; then
    echo
    IFS= read -re -p 'Multiple discs: Which Disc # is this, e.g. 001, 002, 003? ' disknum
    echo
fi

# Specify default disc-drive if blank
if [ -z "$drive" ]; then
    drive="/dev/sr0"
fi

#### GET diskID, the FILENAME, based on callnumber or provided diskID ###

if [[ $barcode != "" ]]; then
    bash barcode-pull.sh -b ${barcode} -f > tmp_${start_datetime}.json
    echo "Using barcode: ${barcode}"
    if $journal; then 
        echo "JOURNAL OR SERIES identified by -J. Using item_data.alternative_call_number"
        diskID=$(jq -r '.item_data.alternative_call_number' "tmp_${start_datetime}.json")
    else
        diskID=$(jq -r '.holding_data.permanent_call_number' "tmp_${start_datetime}.json")
    fi
    echo "callNumber=${diskID}"
elif [[ $MMSID != "" ]]; then 
    bash mmsid-pull.sh -m "${MMSID}" -f > "tmp_${start_datetime}.json"
    echo "Using MMSID: ${MMSID}"
    diskID=$(jq -r '.delivery.bestlocation.callNumber' "tmp_${start_datetime}.json")
    echo "callNumber=${diskID}"
elif [[ $diskID != "" ]]; then
    echo "Using: ${diskID}" # this is a placeholder
fi

#Replace spaces, dots and double dashes with single dashes, remove double quotes
diskID=${diskID// /-}
diskID=${diskID//./-}
diskID=${diskID^^}
diskID=${diskID//--/-}
diskID=${diskID//\"/}
echo "diskID=${diskID}"

if [[ -n "$disknum" ]]; then
    diskID="${diskID}-DISK_${disknum}"
fi
	
echo ""
read -p "Please insert disc into drive and hit Enter"
echo
read -p "Please hit Enter again, once the disc is fully LOADED"
echo

#get CD INFO
cdinfo=$(isoinfo -d -i $drive)
volumeCD=$(echo "$cdinfo" | grep "^Volume id:" | cut -d " " -f 3)
#get blockcount/volume size of CD
blockcount=$(echo "$cdinfo" | grep "^Volume size is:" | cut -d " " -f 4)
if test "$blockcount" = ""; then
    echo
    echo "FAIL: catdevice FATAL ERROR: Blank blockcount" >&2
    #exit 2
fi

#get blocksize of CD
blocksize=$(echo "$cdinfo" | grep "^Logical block size is:" | cut -d " " -f 5)
if test "$blocksize" = ""; then
    echo
    echo "FAIL: catdevice FATAL ERROR: Blank blocksize" >&2
    #exit 2
fi

#### Audio CD #####
if test "$blocksize" = ""; then
    echo
    echo
    echo
    echo
    tracknum=$(cdrdao disk-info -v 0 --device "$drive" | grep "Last Track" | grep -o '[0-9]\+')
    if test $tracknum != ""; then
        audio=true 
        dir="${dir}${diskID}"
        echo "The disc is an audio disc. A directory will be created for the audio tracks: ${dir}"
        echo
        echo "There are ${tracknum} audio tracks in this disc"
        echo
        mkdir -p "$dir"
        touch "$dir/abcde.conf"
        echo "WAVOUTPUTDIR=${dir}" >> "${dir}/abcde.conf"
        abcde -c "$dir/abcde.conf" -d "$drive" -a read
        mv "$dir"/*/*.wav "$dir"
        mv "$dir"/*/status "$dir/${diskID}.log"
        rm -rf "$dir"/*/
        rm "$dir/abcde.conf"       
    fi
    #exit 2
else

##### Display CD INFO #####
    echo ""
    echo "Volume label for CD is: "$volumeCD
    echo "Volume size for CD is: "$blockcount
    echo 
    dir=${dir%/}
    mkdir -p $dir

#### RIP ISO #####
    echo "Ripping CD to ${dir}/${diskID}.iso"
    echo
    dd bs=${blocksize} count=${blockcount} if=$drive of=${dir}/${diskID}.iso status=progress
fi

##### SCANNING CD #####
echo
echo
if [[ $fullsteps == true ]]; then
    response=Y
else 
    read -p "Do you want to scan this disc? [y/n] " response
fi

if [[ $response =~ ^([Yy])+$ ]]; then
    echo "Ejecting drive..."
    eject $drive
    read -p "Please put disc on the scanner and hit any key when ready"
    bash justscan.sh -d $dir -c ${diskID}
else
    echo "Skipping scanning the disc"
fi


#### Pulling metadata #####
echo
if [[ $fullsteps == true ]]; then
    metaresponse=Y
else 
    read -p "Do you want to pull the catalog metadata for this disk [y/n] " metaresponse 
fi

if [[ $metaresponse =~ ^([Yy])+$ ]]; then
    if [[ $barcode != "" ]]; then
        MMSID=$(jq -r .bib_data.mms_id tmp_$start_datetime.json)
        bash mmsid-pull.sh -m alma${MMSID} -f > tmp_$start_datetime.json
        jq -r '.pnx | del(.delivery,.display.source,.display.crsinfo)' tmp_$start_datetime.json > ${dir}/${diskID}.json
    elif [[ $MMSID != "" ]]; then
        jq -r '.pnx | del(.delivery,.display.source,.display.crsinfo)' tmp_$start_datetime.json > ${dir}/${diskID}.json
    else
        echo "No barcode or MMSID provided to pull metadata."
    fi
else
    echo "Skipping metadata pull"
fi

##### Variables for projectlog #####
projectlog="${dir}/projectlog.csv"
isofile=$(find ${dir} -type f -name "${diskID}.iso" -printf "%f\n")
tifffile=$(find ${dir} -type f -name "${diskID}.tiff" -printf "%f\n")
jsonfile=$(find ${dir} -type f -name "${diskID}.json" -printf "%f\n")
checksum=$(md5sum ${dir}/${diskID}.iso | cut -d ' ' -f 1) # Generate md5 checksum for iso files
dateNtime=$(date +"%Y%m%d_%H%M%S")
projectlog_audio="$(dirname "${dir}")/projectlog_audio.csv"
track_no=$(find ${dir} -type f -name "*.wav" | wc -l)
abcdelog=$(find ${dir} -type f -name "${diskID}.log" -printf "%f\n")
title=$(jq -r '.display.title | @text' ${dir}/${jsonfile})

##### Creating non-audio disc projectlog.csv #####
if [[ $audio == false ]]; then
    header="diskID,barcode,iso_file,tiff_file,json_file,iso_checksum,create_time" # Creating projectlog.csv header
    if [ ! -f "$projectlog" ]; then # Check if the file exists; if not, add the header
        echo "$header" > "$projectlog"
    fi

    echo "Item title: ${title}"
    echo
    if [[ $barcode != "" ]]; then
        echo "The item barcode is: ${barcode}"
        echo
    fi
    echo "${diskID},${barcode},${isofile},${tifffile},${jsonfile},${checksum},${dateNtime}" >> "${projectlog}"
    echo
    echo "Files just created in ${dir}:"
    find $dir -type f -name "${diskID}.*"
    echo
    echo "See the updated projectlog in ${projectlog}"
##### Creating audio disc projectlog.csv #####
else
    header="diskID,barcode,total_tracks,tiff_file,json_file,abcde_log,create_time" # Creating projectlog_audio.csv header
    if [ ! -f "$projectlog_audio" ]; then # Check if the file exists; if not, add the header
        echo "$header" > "$projectlog_audio"
    fi

    echo
    echo "Item title: ${title}"
    if [[ $barcode != "" ]]; then
        echo "The item barcode is: ${barcode}"
        echo
    fi
    echo "${diskID},${barcode},${track_no},${tifffile},${jsonfile},${abcdelog},${dateNtime}" >> "${projectlog_audio}"
    echo
    echo "Directory just created:"
    echo "${dir}"
    echo
    if [ $(find $dir -name "track*.wav" | wc -l) == $tracknum ]; then
        echo "The number of tracks in the directory matches the one in the disc"
    else
        echo "The number of tracks in the directory does not match the one in the disc. PLEASE CHECK THE IMAGING COMPLETENESS."
    fi
    #echo "The disc contains ${tracknum} audio files."
    #echo "The directory contains $(find $dir -type f *.wav | wc -l) files"
    echo
    echo "See the following log files:"
    find $dir -type f -name "${diskID}.*"
    echo
    echo "See the updated projectlog_audio in ${projectlog_audio}"
fi

# Remove temporary file
rm "tmp_${start_datetime}.json"
