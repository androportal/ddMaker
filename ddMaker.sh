#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# This program is intended to write/copy images to any media or drive. The
# only dependency to this script is 'zenity'. In most of the GNOME based
# desktops zenity will present, for other desktop environments you need to 
# install it using your package manager. 

# This application is initially written for aakash project to help students
# to create their own bootable GNU/Linux sdcard.

# For more information about GNU/Linux on Aakash, please visit 
# https://github.com/androportal/linux-on-aakash


# Global variables
sizeofDiskBeforeSDCARD=0
sizeofDiskAfterSDCARD=0
sdcardPath=''
ddfilePath=''
password=''
sizeSDCARD=0


###############################################################################


function sudoAccess() {
# Remove any previous sudo passwords 
sudo -K
# In case of wrong password, else condition will fail(return 1)
# and executes from beginning
#------------------------------------------------------------------------------
while true
do
    # Get password from user 
    password=$(zenity --title "Enter your password to continue" --password)
    # zenity dialog button 'Cancel' returns 1, and 'Yes' returns 0.
    # Check for zenity 'Cancel' option
    if [ $? -eq 1 ]
    then
       exit 0
    else
       # sending user entered password to 'echo' command to verify 
       # password, if wrong it will repeat from beginning
       echo $password | sudo -S echo "test">/dev/null
       if [ $? -eq 0 ]
           then
           break
       fi
    fi    
done
#------------------------------------------------------------------------------
}


###############################################################################


function removeSDCARD() {
# The dialog box below will ask user to remove drive(sdcard)
zenity --question --title "ddMaker   Step 1 of 4" \
       --text "Please remove your drive(sdcard) if connected,
then press YES to continue"
# Checking the return value of zenity dialog, same as previous function
if [ $? -eq 1 ] 
then
    exit 0
else
    # This will return size of disk without our media
    sizeofDiskBeforeSDCARD=$(echo $password | sudo -S sfdisk -s\
                           | tail -1 | awk '{print $2}')
fi
}


###############################################################################


function insertSDCARD() {
# The dialog box below will ask user to insert sdcard
zenity --question --title "ddMaker   Step 2 of 4" \
       --text "Now please insert your drive(sdcard) back,\
then press YES to continue"
# Checking the button selected in zenity dialog
if [ $? -eq 1 ]    
then
    exit 0
else
    zenity --info --title "ddMaker info"\
           --timeout 4\
           --text "Waiting for device..."
    # sfdisk prints the total disk space in KB
    sizeofDiskAfterSDCARD=$(echo $password | sudo -S sfdisk -s\
                          | tail -1 | awk '{print $2}')
fi
}


###############################################################################


function SizeofSDCARD() {
# verifying new device by finding difference in size 
# before and after insertion 
sizeSDCARDKbytes=$(($sizeofDiskAfterSDCARD - $sizeofDiskBeforeSDCARD))
# Converting into GB first
sizeSDCARD=$(echo "scale=2;$sizeSDCARDKbytes/1048576" | bc)
# Converting sizeSDCARD to integer, so as to use in conditional statement, 
# if any card is detected it will go inside 'else' statement
if [ $(echo $sizeSDCARD |cut -f 1 -d '.') -eq 0 ]
then
   zenity --info --title "ddMaker info"\
   --text "No media found, please check and restart application"
   exit 0
else
    zenity --question --title "ddMaker   Step 3 of 4"\
    --text "A device of $sizeSDCARD GB is detected, the size will be less \
than actual size of your device. Would you like to continue? \
Press 'YES' to continue or 'NO' to quit !"
    # If 'NO' is selected in zenity dialog then exit
    if [ $? -eq 1 ]
    then
        exit 0
    fi
fi
}


###############################################################################


function ddWrite() {
# Second level of verification. 
# In first level we found the total disk size with and without
# our drive(sdcard), and determined exact size of it.

# In 2nd level, we will find the latest device attached to machine and try to
# cross verify its size with the difference obtained in level 1.     

# In third level, we will limit size of disk size, so to 
# prevent user who accidently use this tool with ext hard disk

# Now as we know that some new device is detected, let's find out the node     
sdcardPath=$(echo $password | sudo -S fdisk -l|grep ^Disk\ /dev/sd | tail -1\
            | awk {'print $2'} | cut -c -8)
# Cross verify the device node with the size of the disk detected
sizeLatestDeviceKbytes=$(echo $(sudo fdisk -l|grep ^Disk\ /dev/sd | tail -1 |\
    awk {'print $5'})/1024 | bc)
if [ $sizeSDCARDKbytes -ne $sizeLatestDeviceKbytes ]
then
    zenity --info \
           --title "ddMaker info"\
           --text "Device mismatch, please try again !"
    exit 0
else
    if [ $sizeSDCARDKbytes -gt 32000000 ]
    then        
    zenity --info \
           --title "ddMaker info"\
           --text "Device detected is more than 32 GB, its just a security \
feature to enable user not to accidently 'dd' to their external hard drives, \
you can override this limit by changing  the 'if' statement of\
ddWrite() function. You can find this bash script at /usr/bin/ddWrite"
    exit 0
    fi
fi    
# This will return the absolute path of the file you want dd
ddfilePath=$(zenity --title "Select your file" --file-selection)
# If file selection is cancelled, then quit application
if [ $? -eq 1 ]
then 
    exit 0
fi   
# Unmounting newly connected device(s), assuming max 9 partitions
umount $sdcardPath[1-9] &> /dev/null
sleep 1
# The main dd process
echo $password | sudo -S dd if=$ddfilePath of=$sdcardPath bs=4096 2>.ddStatus &
if [ $? -eq 1 ]
then
    zenity --info --title "ddMaker info"\
    --text "Something seriously went wrong, please report this issue"
    exit 0
fi
}


###############################################################################


function progressBar() {
(
# overwriting the existing value of device(sdcard) with fdisk output for
# accurate results and converting to GB
sizeSDCARD=$(echo "scale=2;$(echo $password | sudo -S fdisk -l\
|grep ^Disk\ /dev/sd | tail -1 | awk {'print $5'})/1073741824" | bc)

# Key command, this will spit the size of disk copied in ddStatus file 
# mentioned in ddWrite function 
echo $password | sudo -S kill -USR1 `pidof dd` &> /dev/null
# Checking the return status of above command, 1 is failed, 0 is success
#------------------------------------------------------------------------------
while [ $? -eq 0 ]
do 
    # To increase the frequency of progress bar update, reduce the sleep time         
    sleep 5
    # Parsing the content of .ddStatus file to find the percentage 
    # of completion
    echo "$(val=$(cat .ddStatus | tail -n 1 | awk '{print$1}');\
         echo "scale=2;$val/1073741824/$sizeSDCARD*100" | bc | cut -d . -f 1)"
    # Below will check whether dd process is running or not, if it returns
    # code is 1 the while loop will terminate 
    echo $password | sudo -S kill -USR1 `pidof dd` &> /dev/null
done
#------------------------------------------------------------------------------
    zenity --info --title "ddMaker info"\
           --text "Your device is ready, press OK to exit"    
    notify-send "Job successfully completed by ddMaker"
    # Forget password, clear the variable & remove .ddStatus file
    sudo -K; rm .ddStatus
    password=''
    exit 0
) | zenity --progress \
           --title="ddMaker   Step 4 of 4" \
           --text="Performing dd, for a 8GB card it may take 35 minutes ..."\
           --percentage=0\
           --auto-close
    # If 'NO' is selected in progressbar then kill the underlying dd process
    if [ $? -eq 1 ]
    then
        echo $password | sudo -S kill -INT `pidof dd` &> /dev/null
        sudo -K; rm .ddStatus
        password=''
        zenity --info --title "ddMaker info"\
               --text "dd process is cancelled, you may have to format the \
drive to use it again!"
        exit 0
    fi        
}


###############################################################################


# __init__
# Calling functions in order 

sudoAccess
removeSDCARD
insertSDCARD
SizeofSDCARD
ddWrite
progressBar
