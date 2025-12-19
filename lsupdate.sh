#!/bin/bash

# to set write permissions use
# USER:GROUP
USERANDGROUP=

##########################################
# No changes beyond this point necessary #
##########################################

# Make sure only root can run our script
# von https://www.cyberciti.biz/tips/shell-root-user-check-script.html
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Check if argument is provided
if [ -z "$1" ]; then
    printf "Please provide an ZIP file or an URL to the Zip file with the new LimeSurvey Version.\nYou can find the Donloadlink at https://community.limesurvey.org/downloads/\n"
    exit 1
fi

INPUT="$1"
TMP_DOWNLOAD=""

# Check if agument is an url
if [[ "$INPUT" =~ ^https?:// ]]; then
    echo "URL detected: $INPUT"
    TMP_DOWNLOAD="$(mktemp)"
    echo "Loading file ..."

    # Download file quiet
    curl -sSL "$INPUT" -o "$TMP_DOWNLOAD"

    if [ $? -ne 0 ]; then
        echo "Error while downloadinng the file."
        exit 1
    fi

    ZIPFILE="$TMP_DOWNLOAD"
    echo "Finished download: $ZIPFILE"

else
    # Argument isn't a URL
    ZIPFILE="$INPUT"

    if [ ! -f "$ZIPFILE" ]; then
        echo "Provided File '$ZIPFILE' doesn't exist."
        exit 1
    fi
fi

# 1. Make backup of current folder
CURRENT_DIR="$(pwd)"
CURRENT_DIR_NAME="$(basename "$CURRENT_DIR")"

TS="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="../${CURRENT_DIR_NAME}_${TS}"

echo "Backup to: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$CURRENT_DIR"/. "$BACKUP_DIR"/

echo "Backup finished."

# 2. Create temp folder
TMP="$(mktemp -d)"

# Unzip file (quiet + overwrite)
echo "Unizipping ..."
unzip -oq "$ZIPFILE" -d "$TMP"

# Find toplevel in Zip
TOPLEVEL="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

if [ -z "$TOPLEVEL" ]; then
    echo "There was no matching folder in ZIP file."
    rm -r "$TMP"
    exit 1
fi

echo "Topfolder in ZIP file: $TOPLEVEL"

# 3. Kopf files in current directory
cp -a "$TOPLEVEL"/. "$CURRENT_DIR"/

# 4. delete temp folder
rm -r "$TMP"

# if temporary downloaded file, delete it
if [ -n "$TMP_DOWNLOAD" ]; then
    rm "$TMP_DOWNLOAD"
fi

echo "Finished unzipping!"
echo "Backup saved as: $BACKUP_DIR"

# ---------------------------------------------------------
# Automatically detect web server users (only if not set)
# ---------------------------------------------------------

if [ -z "$USERANDGROUP" ]; then
    echo "USERANDGROUP not set – detect running web server ..."

    WEBSERVER=""

    # Check if Apache is running
    if systemctl is-active --quiet apache2 2>/dev/null || \
       systemctl is-active --quiet httpd 2>/dev/null; then
        WEBSERVER="apache"
    fi

    # Check if ngix is running
    if systemctl is-active --quiet nginx 2>/dev/null; then
        WEBSERVER="nginx"
    fi

    # If no service is active: try to detect what is installed
    if [ -z "$WEBSERVER" ]; then
        if command -v apache2 >/dev/null || command -v httpd >/dev/null; then
            WEBSERVER="apache"
        elif command -v nginx >/dev/null; then
            WEBSERVER="nginx"
        fi
    fi

    # If nothing has been detected yet
    if [ -z "$WEBSERVER" ]; then
        echo "No running web server detected – use distribution detection."
        WEBSERVER="unknown"
    else
        echo "Detected Webserver: $WEBSERVER"
    fi

    # distribution detection
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DIST="$ID"
    else
        DIST=""
    fi

    # Determine user+group
    case "$WEBSERVER" in
        apache)
            case "$DIST" in
                ubuntu|debian)
                    USERANDGROUP="www-data:www-data"
                    ;;
                centos|rhel|rocky|almalinux|fedora)
                    USERANDGROUP="apache:apache"
                    ;;
                *)
                    USERANDGROUP="$(ps -eo user,comm | grep -E 'apache2|httpd' | head -n1 | awk '{print $1":"$1}')"
                    ;;
            esac
            ;;
        nginx)
            # Depending on the OS, Nginx typically uses
            # Debian/Ubuntu → www-data
            # RHEL/CentOS → nginx
            if [ "$DIST" = "ubuntu" ] || [ "$DIST" = "debian" ]; then
                USERANDGROUP="www-data:www-data"
            elif [ "$DIST" = "centos" ] || [ "$DIST" = "rhel" ] || [ "$DIST" = "fedora" ] || [ "$DIST" = "rocky" ] || [ "$DIST" = "almalinux" ]; then
                USERANDGROUP="nginx:nginx"
            else
                # Automatisch aus Prozessliste ziehen
                USERANDGROUP="$(ps -eo user,comm | grep nginx | head -n1 | awk '{print $1":"$1}')"
            fi
            ;;
        *)
            # Fallback to knowen Default-User
            if id www-data >/dev/null 2>&1; then
                USERANDGROUP="www-data:www-data"
            elif id apache >/dev/null 2>&1; then
                USERANDGROUP="apache:apache"
            elif id nginx >/dev/null 2>&1; then
                USERANDGROUP="nginx:nginx"
            elif id http >/dev/null 2>&1; then
                USERANDGROUP="http:http"
            else
                echo "WARNING: No matching user/group found. Please set manually!"
                USERANDGROUP=""
                exit 1
            fi
            ;;
    esac

    echo "Detected web server user: $USERANDGROUP"
fi



chown -R "$USERANDGROUP" .
chmod -R 775 tmp/
chmod -R 775 upload/
chmod -R 775 application/config/

echo "Done! Files unzipped into '$CURRENT_DIR', permissions set."
