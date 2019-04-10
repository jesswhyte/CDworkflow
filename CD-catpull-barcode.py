#!/usr/bin/env python3
#IN PROGRESS
### environment-specific Python3 script to pull metadata for gen collection CD-ROMs(i.e. items with callNum)


#######################
###### IMPORTS  #######
#######################

import sys
import argparse 
import os
#import subprocess 
import datetime
import json
import urllib
import re
import csv
from urllib.request import urlopen
from collections import OrderedDict
from PyQt5 import QtGui, QtCore, QtWidgets



#######################
###### ARGUMENTS ######
#######################

parser = argparse.ArgumentParser(
	description ="Script to pull catalog metadata for cd-rom ISOs")
parser.add_argument(
	'-l', '--lib', type=str,
	help='Library, for a list of library IDs, visit ufot.me/libs ', 
	required=True,
	choices=['ARCH','ART','ASTRO','CHEM','CRIM',
	'DENT','OPIRG','EARTH','EAL','ECSL','FCML',
	'FNH','GERSTEIN','INFORUM','INNIS','KNOX',
	'LAW','MDL','MATH','MC','PONTIF','MUSIC',
	'NEWCOLLEGE','NEWMAN','OISE','PJRC','PHYSICS',
	'REGIS','RCL','UTL','ROM','MPI','STMIKES',
	'TFRBL','TRIN','UC','UTARMS','UTM','UTSC','VIC'])
parser.add_argument(
        '-d','--dir', type=str,
        help='Start directory, e.g. /CAPTURED', required=True)
parser.add_argument(
	'-c', '--call', type=str,
	help='Call or Collection Number', required=True)
parser.add_argument(
	'-k', '--key', type=str,
	help='Catkey')

## Array for all args passed to script
args = parser.parse_args()

###############################
########## VARIABLES ##########
###############################

note = "supplementary"
date = datetime.datetime.today().strftime('%Y-%m-%d')
lib = args.lib
mediaType = "CDROM"
callNum = args.call 
callNum = callNum.upper() #makes callNum uppercase
callDum=callNum.replace('.','-') #replaces . in callNum with - for callDum
callNum = re.sub(r".DISK\w","",callNum) # removes the DISK[#] identifier needed for callDum, but only after creating callDum
catKey = args.key
dir = args.dir
callUrl = str(
	"https://search.library.utoronto.ca/search?N=0&Ntx=mode+matchallpartial&Nu=p_work_normalized&Np=1&Ntk=p_call_num_949&format=json&Ntt=%s" % callNum
)
outputPath = callDum+"/"
print(outputPath)
diskpic=outputPath+callDum+".tiff"
print(diskpic)
#note=args.note

#################################
########## CLASS STUFF ##########
#################################

# font colors for notices/warnings, visit https://gist.github.com/vratiu/9780109 for a nice guide to the color codes if you want to change
class bcolors:
    OKGREEN = '\033[92m' #green
    INPUT = '\033[93m' #yellow, used for when user input required
    FAIL = '\033[91m' #red, used for failure
    ENDC = '\033[0m' # end color
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    GREENBLOCK = '\x1b[1;31;40m' # green with background, used for updates user should check (e.g. Title/Cat report)
    ENDGB = '\x1b[0m' #end x1b block

class Dialog(QtWidgets.QDialog):
    def __init__(self,path):
        QtWidgets.QDialog.__init__(self)
        self.viewer = QtWidgets.QLabel(self)
        self.viewer.setMinimumSize(QtCore.QSize(400, 400))
        self.viewer.setScaledContents(True)
        image = QtGui.QPixmap(path)
        image_resized = image.scaledToWidth(600)
        self.viewer.setPixmap(QtGui.QPixmap(image_resized))
        self.editor = QtWidgets.QLineEdit(self)
        self.editor.returnPressed.connect(self.handleReturnPressed)
        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(self.viewer)
        layout.addWidget(self.editor)

    def handleReturnPressed(self):
        self.accept()


####################################
############ FUNCTIONS #############
####################################


#get some json from a URL
def get_json_data(url):
	response = urlopen(url)
	data = response.read().decode()
	return json.loads((data), object_pairs_hook=OrderedDict)


# update the notes
def updateNoteLong():
	global note
	print("\nDISK NOTES")
	print("Note currently set to: \""+bcolors.OKGREEN+note+bcolors.ENDC+"\"")
	print("TIP: Notes are for noting catalog flags or imaging failures")
	print("TIP: Try to be brief and consistent")
	print("TIP: If the resource is \"stand-alone\", please change the note")
	noteupdate = input(bcolors.INPUT+"If you would like to CHANGE the disk notes, please do so now, otherwise hit Enter: "+bcolors.ENDC)
	if noteupdate == "":
		note = str(note)
		print("Note unchanged...")
	else:
		note = noteupdate
		print("Note has been changed to: " + bcolors.OKGREEN + note + bcolors.ENDC)

def updateNote():
	global note
	noteupdate = input(bcolors.INPUT+"If you would like to ADD to the disk notes at this time, please do so, otherwise hit Enter: "+bcolors.ENDC)
	if noteupdate == "":
		note = str(note)
		print("Note unchanged...")
	else:
		note = note + " -- " + noteupdate
		print("Note has been changed to: " + bcolors.OKGREEN + note + bcolors.ENDC)


########################
#####  THE GOODS  ######
########################

### Change working directory to -d flag setting
if not os.path.exists(dir):
	os.makedirs(dir)

os.chdir(dir)

### Check if disk image path already exists (note: looks to CAPTURED/LIB/CALLDUM/ ***NOT*** /CAPTURED/STREAMS/)
### TO DO: should be adapted to check *all* /LIB/CALLDUM/ paths? to avoid dupes across libraries?
### Check if entry exists in project log

with open('projectlog.csv','a+') as inlog:
	reader=csv.reader(inlog)
	for row in reader:
		if not (row):
			continue
		else:
			if callDum == row[1]:
				print(bcolors.INPUT+"log entry exists for that Call Number:"+bcolors.ENDC)	
				print(row)
				replacePath = input(bcolors.INPUT+"Proceed anyway y/n? "+bcolors.ENDC)
				if replacePath.lower() == 'y' or replacePath.lower() == 'yes':
					print(bcolors.OKGREEN+"Replacing "+callDum+" ..."+bcolors.ENDC)
				if replacePath.lower() == 'n' or replacePath.lower() == 'no': 
					sys.exit("No entries updated. Exiting...")	
						
inlog.close()			
			

### Communicate we're going to search the callNum as given...
print("Searching callNum: "+callNum+"...")

### GET THE TITLE AND OTHER METADATA

### do a catcall based on -k catkey or -c callNum

if not catKey: #get that catkey
	call_dic = get_json_data(callUrl)
	num_results = call_dic['result']['numResults']

	# If there are multiple records, prompt for which one is correct
	if num_results > 1:
		# From what we've seen, there should only be one record
		if len(call_dic['result']['records']) > 1:
			sys.exit(bcolors.FAIL+'There\'s more than one record. Script is not designed to handle this case. Please set disk aside or consult catalog'+bcolors.ENDC)
		results_dict = get_json_data(call_dic['result']['records'][0]['jsonLink'])
		catKey = disambiguate_records(results_dict)
	else: #option to take catkey given with -k flag (e.g. if you want to set a custom callnum)
		catKey = call_dic['result']['records'][0]['catkey']

catUrl = str("https://search.library.utoronto.ca/details?%s&format=json" % catKey) #set catalog search url based on catkey

# make a dictionary out of the response from catUrl
# extracts the title value from title key from that dictionary
# will write later in the json dump

#update dictionary for json write
cat_dic = get_json_data(catUrl)
title = cat_dic['record']['title']
imprint = cat_dic['record']['imprint']
catkey = cat_dic['record']['catkey']
description = cat_dic['record']['description']

### PRINT THE METADATA
## x1b stuff is just to make it show up a different color so it's noticeable

print(bcolors.GREENBLOCK + "Confirming:\nTitle: %s\nImprint: %s\nCatKey: %s \nDescription: %s" % (title, imprint, catkey, description) + bcolors.ENDGB)

print("\nDISK LABEL TRANSCRIPTION")
print("TIP: Avoid duplicating information from cat record (e.g. authors, publishers, ISBNs, etc.)")
print("TIP: Avoid quotes please")
print("EXAMPLE: Functions - Programs - Chapter Code - Nodal Demo -- Software to accompany Applied Electronic Engineering with Mathematica -- Requires MATLAB Version 2+ and DOS 2.x")
print("Launching Preview...")
if not os.path.exists(diskpic):
	print(outputPath+callDum+".tiff DOES NOT EXIST")


print("A Window will open to enter the disk label transcription...")
app = QtWidgets.QApplication(sys.argv)
args = app.arguments()[1:]
dialog = Dialog(diskpic)
if dialog.exec_() == QtWidgets.QDialog.Accepted:
	label=str(dialog.editor.text())
else:
	print('ERROR')
	sys.exit(1)

print("Label entered as: "+label)

### update note (set to default as supplementary)

updateNoteLong()


### ADD JSON METADATA ABOUT CAPTURE PROCESS 
## Create dictionary of capture data
capture_dic = {
	'disk':{
	'CaptureDate': date,
	'media': mediaType,
	'label': label,
	'library': lib,
	'diskpic': diskpic}
	}

## delete holdings info (e.g. checkout info) from cat_dic
del cat_dic['record']['holdings']

## write to TEMPmetadata.json for now
with open('TEMPmetadata.json','w+') as metadata:
	cat_dic.update(capture_dic)
	json.dump(cat_dic, metadata)



#########################################
#### END MATTER and METADATA UPDATES ####
#########################################

metadata.close()

## User asked if they'd like to update the notes they entered
updateNote()

replaceMeta = input(bcolors.INPUT+"Confirm you want to create .json and a new log entry y/n? "+bcolors.ENDC)
if replaceMeta.lower() == 'n' or replaceMeta.lower() == 'no':
	# if replaceMeta=N, close out and exit, otherwise carry on
	#metadata.close()
	sys.exit ("-Exiting...")

### Rename our metadata.txt file
newMetadata = callDum + '.json'
os.rename('TEMPmetadata.json', outputPath + newMetadata)
print("Updated metadata file: "+ outputPath + newMetadata)

### Update master log
## TODO: this should really use csv library, I was lazy


## Open and update the masterlog - projectlog.csv
log = open('projectlog.csv','a+')
print("Updating log...")

log.write(
	"\n"+lib+","+callDum+","+str(catKey)+","+mediaType+
	",\""+str(title)+"\",\""+label+"\",\""+note+"\"")
if os.path.exists(diskpic):
	log.write(",pic=OK")
else:
	log.write(",pic=NO")

if os.path.exists(
	outputPath+callDum+".iso"):
	log.write(",iso=OK")
else:
	log.write(",iso=NO")
log.write(",\""+date+"\"")

### Close master log
log.close()

sys.exit ("Exiting...")



