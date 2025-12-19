# LimeSurvey Updater Script

A little script to make LimeSurvey updates even more easy.

---

## Prerequisites
`systemd`, `unzip` and `curl`, both should be installed by default

## Installation
1. Copy the script to your LimeSurvey installation folder on the web server.
2. Make the script executeable `chmod +x lsupdate.sh`

The script has to set the permissions for the new files. It attempts to determine the correct permissions for the combination of operating system and web server. You can overwrite this Line 5. where you can set the owner (user and/or group) as in the chown command in linux,
e.g.: `USERANDGROUP=username:groupname`

⚠️ You have to set this if the script exits with *"WARNING: No matching user/group found. Please set manually!"* ⚠️

---

## Usage
You have two options to run the script:

Run the script as root with the __url__ to the LimeSurvey Update zip __file__ as the argument, the script will download the file automaticly.  
`sudo ./lsupdate.sh https://download.limesurvey.org/latest-master/limesurveyVERSION.zip`

-or-

Run the script as root with the ZIP file as the argument. In this case you have to download the zip file manually
`sudo ./lsupdate.sh limesurveyVERSION.zip`

--- 
## Uninstall

Just delete the script file

--- 
Made with AI help and with ♥️ in Bad Vilbel, Germany
