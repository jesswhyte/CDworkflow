CDworkflow
scripts for optical media workflows
Jess Whyte, 2016+
Feel free to adapt, use, fork, whatever, please cite/credit

*CD-catpull* - searches UTL catalogue using catkey, or barcode, pulls metadata in json format for use in project logs and for packaging with ISO files. 

*check-nimbie (and check-nimbie-barcode, check-nimbie-nocall, etc.)* - after running disks through Nimbie autoloader, verification script to match inserted CD with ISO files. Prompts user to insert a disc, matches it to ISO file, pulls metadata from UTL catalog. Includes option to scan the disk. Note: this needs to be tightened up. 

*inventory.sh* - scan barcode, pulls metadata (catkey, call #, title) and inserts into CSV. Used for creating inventories of disks we are working on. 

*justscan.sh* - sometimes you just need to scan a thing and have that scan go into the right directory. 

*single-barcode.sh/single-cd.sh* - script for making ISO package (metadata, ISO file, scan, projectlog entry) for CD, pulls metadata based on barcode. 

*single-cd-nocall.sh* - script for making an ISO package (metadata, ISO file, scan, projectlog entry) for a CD that is not in the catalog, e.g. a stack from an archival collection. 


*TODO:* consolidate cd-catpull-barcode and cd-catpull, can be functions in shared. Ditto for check-nimbie and all versions.

*TODO:* If barcode scanned is the same as last barcode scanned (or any previous barcode?), stop and prompt user to ask if they meant to scan the same disk twice or if it's a different disk. This prevents the double scan/double entry. 

*TODO:* consider removing projectlog entries all together, can just pull that metadata after based on file creation dates. This might mean missing failed disks, but these could be physically labelled and set aside?? Or maintained on a separate list of fails. 
