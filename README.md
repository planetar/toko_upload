# Versioning and Archiving Marlin Builds and Uploading to Octoprint Printer
This project is still in search of a handy name and the headline is more like a desciption.
## The Problem: Which build had what settings?
Marlin has so many features and settings you can activate or modify and of course you do. Some builds run nice, some even better and some not at all, but once it's been built you can hardly tell what's inside. And stepping back from a failed path to a good one 2,3 builds before can become a challenge unless you keep really good notes of it all.
### Versioning and Storing
I got bitten by that and decided to introduce some visual versioning to my Marlin builds, plus storing the Configuaration files for each build next to the version tag.
Doing this can be easily accomplished with a filemanager but that still demands some discipline. And that, in my experience, comes easier if it's sweetened by being comfortable.
### Making it Comfortable
And what would be comfortable when building a new firmware for my 3d-printer? Well, sitting on my desk, issue a command and the versioning is checked, the configuartion stored, everything on the way is checked (is the print host with octoprint reachable? Is the printer on?) and then tu pload the firmware onto the printer and restart the printer, all in one go.
So, this is what this script aims to accomplish.
## Visible Expectable Version Tags
Where to put it? There is the CUSTOM_MACHINE_NAME which is shown in the display as soon as Marlin has booted. It may tell you your printer's brand in case you forgot, and/or the mainboard Marlin is running on. Seems like the right place to hold the version tag of the firmware build.
For a version a simple integer, incremented with each build would suffice, but I felt it more useful to also include the date so I went for YYYY-mm-dd_lfd where lfd is the running number of builds at that day. 2021-05-18_1


