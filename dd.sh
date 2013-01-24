#!/bin/bash

sizeofDiskBeforeSDCARD=0
sizeofDiskAfterSDCARD=0
sdcardPath=''
ddfilePath=''

function removeSDCARD() {
# The dialog box below will ask user to remove sdcard
zenity --question --title "ddMaker   Step 1 of 4" --text "Please remove your sdcard if connected, then press YES to continue"
# Checking the return code of zenity, if 0 its OK, 1 is NO !
if [ $? -eq 1 ] 
then
    exit 0
else
    sizeofDiskBeforeSDCARD=$(df -h --total | tail -n 1 | awk '{print $2}' | cut -c -3)
fi
}

###############################################################################

function insertSDCARD() {
# The dialog box below will ask user to insert sdcard
zenity --question --title "ddMaker   Step 2 of 4" --text "Now please insert your sdcard back, then press YES to continue"
# Checking the return code of zenity, if 0 its OK, 1 is NO !
if [ $? -eq 1 ] 
then
    exit 0
else
    zenity --info --title "ddMaker info" --timeout 3 --text "Waiting for device..."
    sleep 3
    sizeofDiskAfterSDCARD=$(df -h --total | tail -n 1 | awk '{print $2}' | cut -c -3)
fi
}

###############################################################################

function SizeofSDCARD() {
sizeSDCARD=$(($sizeofDiskAfterSDCARD - $sizeofDiskBeforeSDCARD))
if [ $sizeSDCARD -eq 0 ]
then
   zenity --info --title "ddMaker info" --text "Restarting application as no sdcard found !"
   removeSDCARD
   insertSDCARD
else
    zenity --question --title "ddMaker   Step 3 of 4" --text "A sdcard of $sizeSDCARD GB is detected, the size shown will be less than actual size of your sdcard. Would you like to continue and dd your image to this sdcard ?  Press YES to dd image or NO to quit !"
    if [ $? -eq 1 ]
    then
    exit 1
    fi
fi
}

###############################################################################

function ddWrite() {
if [ $? -eq 0 ]
then
    
    sdcardPath=$(ls /dev/sd* | tail -n 1 | cut -c -8)
    ddfilePath=$(zenity --title "Select you image file to be dd'ed on sdcard " --file-selection)
    
    sudo -K
    while true
        do
        pass=$(zenity --title "Enter your password to continue" --password)
        # Return code is 1 when user choose 'cancel', if select 'Yes' return code is 0
        if [ $? -eq 1 ]
        then
            exit 0
        else
            umount $sdcardPath[1..9]
            sleep 1
            echo $pass | sudo -S  dd if=$ddfilePath of=$sdcardPath bs=4096 
            if [ $? -eq 0 ]
                then
                break
            fi
        fi    
                          
        done
else
    exit 0
fi    
}

###############################################################################

function progressBar() {

#Yes to come
#kill -USR1 `pgrep ^dd$` |  awk '{print $1}' 
zenity --progressbar
# cat tmp | awk '{print $3}'| tail -n 2 -c -4 | head -1

}

###############################################################################

# __init__

removeSDCARD
insertSDCARD
SizeofSDCARD
ddWrite
progressBar
