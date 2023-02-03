CDworkflow
scripts for optical media workflows
Jess Whyte, 2016+, updated Feb 2023
Feel free to adapt, use, fork, whatever, please cite/credit

**barcode-pull.sh** - searches catalogue using barcode, pulls metadata in json format. 

**check-nimbie.sh** - after running disks through Nimbie autoloader, verification script to match inserted CD with ISO files. Prompts user to insert a disc, matches it to ISO file, pulls metadata from UTL catalog. Includes option to scan the disk.

**inventory.sh** - scan barcode, pulls metadata (mmsid, call #, title) and inserts into CSV. Used for creating inventories of disks we are working on. 

**justscan.sh** - scan a thing and have that scan go into the right directory. 

**mmsid-pull.sh** - searches catalogue using MMSID, pulls metadata in json format. 

**single-cd.sh** - script for making ISO package (metadata, ISO file, scan) for CD, pulls metadata based on barcode or MMSID if provided

**oldscripts directory** - stuff I'm not ready to throw away yet
