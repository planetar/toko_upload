# Versioning and Archiving Marlin Builds and Uploading to Octoprint Printer

## The Problem: Which build had what settings?
Marlin has so many features and settings you can activate or modify and of course you do. Some builds run nice, some even better and some not at all, but once it's been built you can hardly tell what's inside. And stepping back from a failed path to a good one 2,3 builds before can become a challenge unless you keep really good notes of it all.
### Versioning and Storing
I got bitten by that and decided to introduce some visual versioning to my Marlin builds, plus storing the Configuration files for each build next to the version tag.
Doing this can be easily accomplished with a filemanager but that still demands some discipline. And that, in my experience, comes easier if it's sweetened by being comfortable.
### Making it Comfortable
And what would be comfortable when building a new firmware for my 3d-printer? Well, sitting at my desk, issue a command and the versioning is checked, the configuration stored, everything on the way is tested (did I remember to update the version tag? Is the print host with octoprint reachable? Is the printer on? Is it connected to octoprint?) and then to upload the firmware onto the printer and restart the printer, all in one go.
So, this is what this script aims to accomplish.
## Visible Expectable Version Tags
Where to put it? There is the CUSTOM_MACHINE_NAME which is shown in the display as soon as Marlin has booted. It may tell you your printer's brand in case you forgot, and/or the mainboard Marlin is running on. Seems like the right place to hold the version tag of the firmware build. Marlin loops display when the text is longer than the space for it on display so nothing gets hurt when we add like 12 chars at the very start of it.
For a version a simple integer, incremented with each build would suffice, but I felt it more useful to also include the date so I went for YYYY-mm-dd_lfd where lfd is the running number of builds at that day. It looks like 2021-05-18_1.
Given the way the script checks for the versioning tag you need to be a bit anal about it: it should sit exactly at the start of the value string for CUSTOM_MACHINE_NAME, immediately after the quote, and it needs a white space behind it. The line looks like this at my Configuration.h:
```
#define CUSTOM_MACHINE_NAME "2021-06-12_1 toko SKR-mini-E3_V1.2" 

```
(toko is the name of that thing in my namespace)

## Context
The script links 3 different 'boxes' and to make that work successfully a number of requirements need to be matched 
### desktop
It was developed on a Linux desktop (where, among other things,  VSCode with PlatformIO runs) and at times new Marlin builds get compiled here. Marlin sources sits at some path of that computer and the folder to keep the version archive is a path on that machine, too. In theory both MacOS and Windows desktops should do as well with win having a linux sub system on board and OSX a \*nix itself. It hasnt been tested, though. 
### print host
Next, sharing the same lan, is another linux computer, a raspberry (3B) on octopi/octoprint which is the print host and controls the 3d-printer. print host and desktop communicate, among other protocols, via ssh and scp and it is important that there is a working public/private key authorization in place so you don't have password dialogs or something popping up when data are transfered. This script assumes octoprint of a fairly recent version running on the print host. The script calls the octoprint - api and has not been tested with versions prior 1.6.1. (Which is not to say that earlier versions won't work, I just don't know where the limit is)
Further, *usbmount* needs to be installed and configured on  the print host.
### printer
The latter happens to be an Ender 3 with a BigTreeTech SKR E3 mini v1.2 mainboard. 2 characteristics of that board are important here: 
- it will automatically (try to) flash itself with the content of a file "firmware.bin" if it finds such a file at the root of the sd-card at boot.
- it is ready to export the sc-card via usb to the print host where that is availabel at /media/usb0
You may have to prime the printer flashing an \_USB-style of firmware so the sharing of the sd-card works as this is crucial to make the upload work

### Install usbmount on the print host
```
- apt-get install usbmount
- sudo nano /etc/usbmount/usbmount.conf
- FS_MOUNTOPTIONS="-fstype=vfat,gid=pi,uid=pi,dmask=0022,fmask=0111"
- sudo systemctl edit systemd-udevd
-> [Service]
    PrivateMounts=no
    MountFlags=shared
- sudo systemctl daemon-reload
- sudo service systemd-udevd --full-restart
```
