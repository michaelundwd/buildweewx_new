#!/bin/bash
# shell file to reset dates for relevant graphs dependent on the type of weewx (live or test)
# weewx_type is defined by line in weewx.conf starting '# filename=weewx.conf_' # NOTE last 4 characters start at position 22
# shell is designed to work from within the container, otherwise WEEWX_TYPE will not be defined
# version 1 - modified 13/12/2025

# Check that $WEEWX_ROOT has been set by the container's docker file

if [$WEEWX_ROOT -eq ""]
then
  echo "WEEWX_ROOT has not been defined"
  exit
fi

# determine whether live or test system
echo "Start of weegraphs.sh looking in $WEEWX_ROOT"

FILENAME=$(grep '^# filename=' $WEEWX_ROOT/weewx.conf)
WEEWX_TYPE=${FILENAME:22:4}

echo "Resetting json files in $WEEWX_TYPE system"

#chose location of json files according to weewx type

case $WEEWX_TYPE in
    "live")
        JSON_FOLDER="$WEEWX_ROOT/public_html/json"
        FTP_LAST="$WEEWX_ROOT/public_html/#FTP.last"
        ;;
    "test")
        JSON_FOLDER="$WEEWX_ROOT/public_html/test/json"
        FTP_LAST="$WEEWX_ROOT/public_html/test/#FTP.last"
        ;;
    *)
        echo "$WEEWX_TYPE is not a valid WEEWX_TYPE"
        exit
        ;;
esac

# define the variables for the cleanup

yyyy=$(date +"%Y")
mm=$(date +"%m")
dd=$(date +"%d")
hh=$(date +"%H")

hourly="$yyyy$mm$dd$hh"
daily="$yyyy$mm$dd"00
monthly="$yyyy$mm"0100
yearly="$yyyy"010100
touch="touch -m -t "

n05="05.00"
n10="10.00"
n15="15.00"
n20="20.00"
n25="25.00"
n30="30.00"
n35="35.00"
n40="40.00"
n45="45.00"
n50="50.00"
n55="55.00"

# Assign new modified dates to json files

$touch$daily$n05 $JSON_FOLDER/yesterday.json
$touch$hourly$n10 $JSON_FOLDER/week.json
$touch$hourly$n15 $JSON_FOLDER/month.json
$touch$daily$n20 $JSON_FOLDER/year.json
$touch$daily$n25 $JSON_FOLDER/annual.json
$touch$daily$n30 $JSON_FOLDER/summary.json

# Remove FTP_LAST to ensure that ftp uploads all json files to website

rm $FTP_LAST

echo "Resets the modified date/time for 6 files in $JSON_FOLDER"
echo "This forces all graphs to be updated at the relevant minutes past the hour"
echo yesterday.json ".$daily$n05"
echo week.json      "......$hourly$n10"
echo month.json     ".....$hourly$n15"
echo year.json      "......$daily$n20"
echo annual.json    "....$daily$n25" 
echo summary.json   "...$daily$n30" 
echo $FTP_LAST was also cleared to reset ftp upload
