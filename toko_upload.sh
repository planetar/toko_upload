#!/bin/bash
###################################################################################################
#
#  toko_upload.sh
#
#########################
#
# upload a new firmware build to the printer and archive it as a new version in an archive folder
# 
# v 0.1  2021-05-18  initial
# v 0.2  2021-05-19  caught some errors, 
#                    curl into octoprint api to reboot printer
# v.0.3  2021-06-11  toko_upload_settings external
#                    DRY_RUN
#                    test / do connect the printer to octoprint
#                    cleanup of output
#
########################
#
# predictable, expectable version tag
# ie 2021-05-18_1  YYYY-mm-dd_lfd  lfd tells build # at that date
# folders in the archive directory at runtime define which is the next free tag
#
# in case of errors, checking the state of $VERSION_ARCHIV_PATH is prime
#
#################################################################################################
#
# TBD: 
#      intro checks on DRY_RUN to help with testing
#      implement check for printer connected in octoprint


version=0.3

# this is overridden by the _settings
DRY_RUN=false

# settings
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/toko_upload_settings"

# the firmware build version tag: preparation
printf -v DATUM '%(%Y-%m-%d)T' -1 
ATMPT=1
DATE_EXP=$DATUM"_"$ATMPT

# show up
echo "toko_update $version : Upload and archive Marlin firmware updates"
echo 
echo "SourcePath:    $SOURCE_PATH"
echo "BuildDir:      $BUILD_DIR"
echo "ArchivPath:    $VERSION_ARCHIV_PATH"
echo "REMOTE_DEST:   $REMOTE_DEST"
echo
echo


# does a folder in VERSION_ARCHIV_PATH named like $DATE_EXP exist? Y: incr ATMPT, try again until N: we have a new name, create folder
echo "determining current expectable version tag from today's date and archived versions.:"
FOUND=0
while [[ FOUND -eq 0 ]]; do
    DATE_EXP=$DATUM"_"$ATMPT
    CUR_ARCHIV_PATH=$VERSION_ARCHIV_PATH/$DATE_EXP
    echo "      testing $CUR_ARCHIV_PATH"
    
    if [[ -d $CUR_ARCHIV_PATH ]]
    then
        echo "       $CUR_ARCHIV_PATH exists";
        ATMPT=$((ATMPT+1));
    else
        FOUND=1;
        # jetzt oder spaeter
        #mkdir -p $CUR_ARCHIV_PATH;
        echo "      $CUR_ARCHIV_PATH not yet there"
        break;
    fi

done

# version tag completed and archive path verified
echo
echo so that would be "versiontag $DATE_EXP and storage at $CUR_ARCHIV_PATH"
echo

#does the Configuration.h at $SOURCE_PATH contain the $DATE_EXP ?
echo "Check version tag of current source."
CONF_VERSION=$(grep '#define CUSTOM_MACHINE_NAME' $SOURCE_PATH/Configuration.h | awk '{print $3}'| cut -c2-)

echo ""

IDENTICAL_FILES=0

if [ $CONF_VERSION == $DATE_EXP ]; then
  echo "version expressions are as expected."
  echo
    #mkdir -p $CUR_ARCHIV_PATH;
    echo "$CUR_ARCHIV_PATH to be created "
else
  echo "version expressions differ"
  echo "Configuration.h is tagged $CONF_VERSION"
  echo "predictable version is    $DATE_EXP"
  echo
  
  # does a folder exist for the version expression we found in the config?
  echo "Check if there is an archive with the source's version tag:"
  echo
  
  TEST_ARCHIV_PATH=$VERSION_ARCHIV_PATH/$CONF_VERSION
    if [[ -d $TEST_ARCHIV_PATH ]]
    then  
        echo "archive folder exists at $TEST_ARCHIV_PATH"
  
        FILE1=Configuration.h
        FILE2=Configuration_adv.h
        FILE3=firmware.bin
 
        ARCHIVE_FILE1_Path=$TEST_ARCHIV_PATH/Configuration.h
        ARCHIVE_FILE2_Path=$TEST_ARCHIV_PATH/Configuration_adv.h
        ARCHIVE_FILE3_Path=$TEST_ARCHIV_PATH/firmware.bin
        SOURCE_FILE1_Path=$SOURCE_PATH/Configuration.h
        SOURCE_FILE2_Path=$SOURCE_PATH/Configuration_adv.h
        SOURCE_FILE3_Path=$BUILD_DIR/firmware.bin
        
        IS_SOURCE_NEWER=0
        IDENTICAL_FILES=0
        
        if [[ -f "$ARCHIVE_FILE1_Path" ]]; then
            echo "$FILE1 exists."
            if [[ $SOURCE_FILE1_Path -nt $ARCHIVE_FILE1_Path ]]; then
                echo "but has been changed after archiving."
                IS_SOURCE_NEWER=$((IS_SOURCE_NEWER+1));
            else
                IDENTICAL_FILES=$((IDENTICAL_FILES+1))
            fi
        fi
        echo
        if [[ -f "$ARCHIVE_FILE2_Path" ]]; then
            echo "$FILE2 exists."
            if [[ $SOURCE_FILE2_Path -nt $ARCHIVE_FILE2_Path ]]; then
                echo "but has been changed after archiving."
                IS_SOURCE_NEWER=$((IS_SOURCE_NEWER+1));
            else
                IDENTICAL_FILES=$((IDENTICAL_FILES+1))
            fi
        fi
        echo
        if [[ -f "$ARCHIVE_FILE3_Path" ]]; then
            echo "$FILE3 exists."
            if [[ $SOURCE_FILE3_Path -nt $ARCHIVE_FILE3_Path ]]; then
                echo "but has been changed after archiving."
                IS_SOURCE_NEWER=$((IS_SOURCE_NEWER+1));
            else
                IDENTICAL_FILES=$((IDENTICAL_FILES+1))
            fi
        fi
        echo
        
        if [[ IS_SOURCE_NEWER -gt 0 ]]; then
            echo
            echo "An archive was created following the last build but the config was changed since."
            echo "At least $IS_SOURCE_NEWER file/s are newer."
            echo
            echo "Please update CUSTOM_MACHINE_NAME in $FILE1 to start with $DATE_EXP, build it and try again."
            exit;
        fi
    else
        echo "A version tagged $CONF_VERSION has never been archived but it's not the predictable one either."
        echo "Please update CUSTOM_MACHINE_NAME in $FILE1 to start with $DATE_EXP, build it and try again."
        exit;
    fi    
fi

# looks like we're just duplicating things which may be ok when testing but in real life??
if [ $IDENTICAL_FILES -eq 3 ]; then
    echo
    echo "It looks like this run is simply duplicating what has ben stored and uploaded already. Is this intended?"
    echo
    CNT=0
    if "$DRY_RUN"; then
        CNT=5
    else
        CNT=15
    fi

    while [[ $CNT -gt 0 ]] ; do
        sleep 1;
        echo -ne \\r"$CNT sec to stop with ^C"
        CNT=$((CNT-1));
    done
fi

echo
echo "Looks good so far, now checking if destination  $REMOTE_DEST is reachable"
echo

DUMMYPATH="/tmp/access.flag"
echo $DATE_EXP>$DUMMYPATH

RESULT=$((scp $DUMMYPATH $REMOTE_DEST)  2>&1)

# printer aus: scp: /media/usb0/dummy: Permission denied
# rechner aus; ssh: connect to host (hostname) 22: Invalid argument
#              lost connection



if [[ $RESULT == *"Permission denied"* ]]; then
  echo "The printer appears to be offline,"
  #echo "Please make sure its on and the sd-card is shared to $PRINT_HOST:/media/usb0"
  #echo "Then try again."
  #exit;
  echo "Trying to switch it on. This will take like 20 sec.";
  echo
  /usr/bin/mosquitto_pub  -h $MOSQUITTO_HOST -u $MOSQUITTO_USER -P $MOSQUITTO_PASSWD -t "$MOSQUITTO_TOPIC_POWERSWITCH" -m 'ON'
  CNT=0
  WAITLIMIT=50
  
  while [[ $RESULT == *"Permission denied"* ]]; do
    sleep 1;
    RESULT=$((scp $DUMMYPATH $REMOTE_DEST)  2>&1);
    CNT=$((CNT+1));
    echo -ne \\r"waiting $CNT sec with $RESULT";
    if [[ $CNT -gt $WAITLIMIT ]]; then
        echo "overstepped the limit of $WAITLIMIT sec, giving up"
          echo "Please make sure the printer is powered on and the sd-card is shared to $PRINT_HOST:/media/usb0"
          echo "Then try again."
          exit;
    fi
  done
  ssh pi@$PRINT_HOST 'sh -c "if [ -f /media/usb0/access.flag ] ; then rm  /media/usb0/access.flag  ; fi" '
fi

if [[ $RESULT == *"Invalid argument"* ]]; then
  echo "The host appears to be unreachable,"
  echo "Please make sure it's on and you can ssh pi@$PRINT_HOST"
  echo "Then try again."
  exit;
fi

if [[ $RESULT != "" ]]; then
  echo "some other error occurred, scp returned:"
  echo "$RESULT"
  echo "Please try to make that go away - "
  echo "Then try again."
  exit;
fi

echo
echo "Fine, tests went successfully, let's try our luck then!"

## all was testing before, now things get actually touched




ARCHIVE_FILE1_Path=$CUR_ARCHIV_PATH/Configuration.h
ARCHIVE_FILE2_Path=$CUR_ARCHIV_PATH/Configuration_adv.h
ARCHIVE_FILE3_Path=$CUR_ARCHIV_PATH/firmware.bin
SOURCE_FILE1_Path=$SOURCE_PATH/Configuration.h
SOURCE_FILE2_Path=$SOURCE_PATH/Configuration_adv.h
SOURCE_FILE3_Path=$BUILD_DIR/firmware.bin       

echo "copying..."


if "$DRY_RUN"; then
    echo "DRY_RUN"
    
    echo "mkdir -p $CUR_ARCHIV_PATH"

    #echo "cp $SOURCE_FILE1_Path $ARCHIVE_FILE1_Path"
    echo "cp $SOURCE_FILE1_Path $ARCHIVE_FILE1_Path"
    echo "cp $SOURCE_FILE2_Path $ARCHIVE_FILE2_Path"
    echo "cp $SOURCE_FILE3_Path $ARCHIVE_FILE3_Path"

    echo "scp $SOURCE_FILE3_Path $REMOTE_DEST"
    echo "scp -r $CUR_ARCHIV_PATH $REMOTE_DEST"
    
else
   

    # create archive folder
    echo $(mkdir -p $CUR_ARCHIV_PATH)

    #echo "cp $SOURCE_FILE1_Path $ARCHIVE_FILE1_Path"
    echo $(cp $SOURCE_FILE1_Path $ARCHIVE_FILE1_Path)
    echo $(cp $SOURCE_FILE2_Path $ARCHIVE_FILE2_Path)
    echo $(cp $SOURCE_FILE3_Path $ARCHIVE_FILE3_Path)

    echo $(scp $SOURCE_FILE3_Path $REMOTE_DEST)
    echo $(scp -r $CUR_ARCHIV_PATH $REMOTE_DEST)

fi


echo "If there were errors above, manually remove the last folder in the archive, correct the problem and restart."
echo "If that went through w/o errors the bulk is done. "
echo

sleep 1

echo "Checking now if the printer is connected to octoprint and try to connect if not."
echo

# copying is done, the printer needs a reboot. 
# but this will only work if the printer is on and connected in octoprint, else it says {"error":"Printer is not operational"}
# and then the show fails

## TBD
## call octoprint API to check printer connection state and if not connected, do connect it.

# connect
curl -s -X POST  -H "Content-Type: application/json" -H "X-Api-Key":"$OCTOPRINT_X_API_KEY" -d '{"command":"connect"}' http://$PRINT_HOST/api/connection
sleep 2

RESULT=$(curl -s http://kiwi.intern/api/connection?apikey=ADF25F24F82A49E48CCC0C3C95D25DF9)
#echo "result: $RESULT"


CNT=0
WAITLIMIT=15

  while [[ $RESULT == *'"state":"Closed"'* ]]; do
    sleep 1;
    RESULT=$(curl -s http://kiwi.intern/api/connection?apikey=ADF25F24F82A49E48CCC0C3C95D25DF9);
    if [[ $RESULT == *'"state":"Closed"'* ]]; then
        STATE="not connected"
    fi

    CNT=$((CNT+1));
    echo -ne \\r"waiting $CNT sec and the printer is $STATE to octoprint";
    if [[ $CNT -gt $WAITLIMIT ]]; then
        echo "TIMEOUT after $WAITLIMIT sec, giving up"
          echo "Please make sure the printer is connected to octoprint $PRINT_HOST"
          echo "Then try again."
          exit;
    fi
  done

echo "  the printer is connected to octoprint on $PRINT_HOST."
echo "  we should be safe to finally tell octoprint to tell the printer to reboot."
echo

## we should be safe to finally tell octoprint to tell the printer to reboot

curl -s -X POST  -H "Content-Type: application/json" -H "X-Api-Key":"$OCTOPRINT_X_API_KEY" -d '{"command":"M117 about to reboot in 5 sec"}' http://$PRINT_HOST/api/printer/command
sleep 5
curl -s -X POST  -H "Content-Type: application/json" -H "X-Api-Key":"$OCTOPRINT_X_API_KEY" -d '{"command":"M997"}' http://$PRINT_HOST/api/printer/command

echo "the printer should be booting up, this may take like a minute"
echo
echo

CNT=0
WAITLIMIT=100

# wait for the printer to come up again
RESULT=$((scp $DUMMYPATH $REMOTE_DEST)  2>&1);
while [[ $RESULT == *"Permission denied"* ]]; do
sleep 1;
RESULT=$((scp $DUMMYPATH $REMOTE_DEST)  2>&1);
CNT=$((CNT+1));
echo -ne \\r"waiting $CNT sec ";

if [[ $CNT -gt $WAITLIMIT ]]; then
    echo
    echo "timeout ($WAITLIMIT sec) exceeded, giving up"
        echo "Please make sure the printer is powered on and the sd-card is shared to $PRINT_HOST:/media/usb0"
        echo "Then check /media/usb0 on leftovers manually"
        exit;
fi
done

echo
echo "the printer is up, some cleanup and you'll see the content of the sd-card"
echo "(At times the bootloader fails to rename the firmware.bin. This script renames "
echo "it to firmware.OFF if it finds such a file so your printer won't reflash with every boot.)"
echo

# test for firmware.bin still there and move it out of the way if so
ssh pi@$PRINT_HOST 'sh -c "rm /media/usb0/access.flag;if [ -f /media/usb0/firmware.bin ] ; then mv  /media/usb0/firmware.bin /media/usb0/firmware.OFF ; fi;" '


ssh pi@$PRINT_HOST 'sh -c "ls -l /media/usb0/"'

echo
echo "fertig!"
echo


#echo "Now go to octoprint/terminal and send a M997 to the printer."
#echo "And when reconnected, pls. check $PRINT_HOST:/media/usb0 for the file firmware.bin"
#echo "If the printer did not, rename it manually to FIRMWARE.CUR. Or remove it, it's archived."

exit;



