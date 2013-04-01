#!/bin/sh
#
# Jetib Login Tool (v0.4)
# 
# Author: Timothy White http://weirdo.bur.st/
# 
# This script will log you in to a jetib (Jet Internet Billing) system
#
#
# It will first attempt to load your credentials from .jetibcreds
# If this file doesn't exist, it will fall back to asking for your
# credentials first via zenity, and if zenity isn't installed then via
# normal shell input
#
# curl must be installed and in your path for this tool to work

#### Changelog
#
#   0.4
#    * Added Libnotify stuff
#
#   0.3
#    * Bug fixes to grep regex
#
#   0.2
#    * Fix up string handling and screen scraping of status text
#    * Make Ctrl-C handling look cleaner
#
#   0.1 
#    * Initial Release
#
#
#
#


# Curtin University settings are as follows
#DOMAIN="jetib.curtin.edu.au"
#LOGIN_PAGE="/curtin/portal/login"
#STATUS_PAGE="/curtin/portal/popup_text_refresh"
#OGOFF_PAGE="/curtin/portal/logout"

DOMAIN="jetib.curtin.edu.au"
LOGIN_PAGE="/curtin/portal/login"
STATUS_PAGE="/curtin/portal/popup_text_refresh"
LOGOFF_PAGE="/curtin/portal/logout"

# .jetibcreds file in users home directory
# containing login credentials in the format of
# username:password
JETLOGIN="$HOME/.jetibcreds"

# User agent to pretend to be (just incase they block scripts, pretend to be a browser)
USER_AGENT="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.1.1) Gecko/20090715 Firefox/3.5.1 (.NET CLR 3.5.30729)"

# Find location of curl and zenity
CURL=$(which curl)
ZENITY=$(which zenity)
NOTIFY_BIN=$(which notify-send)

if [ -x "$NOTIFY_BIN" ]
then
    notify() {
        $NOTIFY_BIN -t 10000 -i network 'JetIB Login' "$1"
    }
else
    notify() {
        true
    }
fi


# Catch ctrl_c requests and logout and cleanup
ctrl_c() {
    stty echo # Turn TTY echo back ON!
    # (Maybe we caught Ctrl-c when they were supposed to be entering password)
    echo ""
    echo "Logging you off..."
    notify "Logging you off..."
    # Send logoff request
    logoff=$(curl -s https://$DOMAIN$LOGOFF_PAGE -c cookies.txt -b cookies.txt |grep "<p>"|sed -e :a -e 's/<[^<]*>/ /g;/</{N;s/\n/ /;ba;}' |sed 's/^[ \t]*//;s/[ \t]*$//' )
    notify "$logoff"
    echo $logoff
    
    # Clear cookies file
    rm cookies.txt
    exit 0
}

status_page() {
    # Get status page text
    status_text=$(curl -s https://$DOMAIN$STATUS_PAGE -c cookies.txt -b cookies.txt)
    
    # Process status page text
    remaining=$(echo "$status_text" | grep remaining|egrep -o '[0-9.]+')
    loggedinas=$(echo "$status_text" | grep "logged in as"|egrep -o '<em>.*</em>'|egrep -o '[0-9]+')
    quota=$(echo "$status_text" | grep -i quota|egrep -o ':[^<]*' |egrep -o '[0-9.]+')
    thismonth=$(echo "$status_text" | grep -i "this month"|grep -o '[^<]*'|grep 'this'|egrep -o '[0-9.]+')
    thismonth=${thismonth#*:} # Strip everything before :
    thismonth=${thismonth#"${thismonth%%[! ]*}"} # Strip White Space
    thissession=$(echo "$status_text" | grep -i "this session"|grep -o '[^<]*'|grep 'this'|egrep -o '[0-9.]+')
    thissession=${thissession#*:} # Strip everything before :
    thissession=${thissession#"${thissession%%[! ]*}"} # Strip White Space
    
    # Display status page
    clear
    echo "Logged in as:      $loggedinas"
    echo "Quota Remaining:   $remaining MB"
    echo "Monthly Quota:     $quota MB"
    echo "Used this month:   $thismonth MB"
    echo "Used this session: $thissession MB"
    echo ""
    echo "Press Ctrl-C to disconnect"
    
    if [ "x$displayed_notify" = "xfalse" ]
    then
        notify "Logged in as:      $loggedinas
Quota Remaining:   $remaining MB
Monthly Quota:     $quota MB
Used this month:   $thismonth MB"
    fi

}


if [ -x "$CURL" ]
then
    /bin/echo -ne "\033]0;JetIB\007" # Bash only code
    if [ -r "$JETLOGIN" ]
    then
        # .jetibcreds file in users home directory
        # containing login credentials in the format of
        # username:password
        creds=$(cat $JETLOGIN)
        USERNAME=${creds%%:*}
        PASSWORD=${creds#*:}

    else
        # Credentials not saved, ask for them
        if [ -x "$ZENITY" ]
        then
            # Use Zenity to ask for credentials
            USERNAME=$(zenity --entry --title="Internet Login" --text="Username")
            PASSWORD=$(zenity --entry --title="Internet Login" --text="Password" --hide-text)
        else
            # Zenity not installed, falling back to shell to ask for credentials
            echo -n "Username: "
            read USERNAME
            echo ""
            echo -n "Password: "
            # trap ctrl-c and call ctrl_c()
            trap ctrl_c INT 
            stty -echo # Turn off TTY echo so password is hidden
            read PASSWORD
            stty echo # Turn TTY echo back ON!
            echo "" # force a carriage return to be output
        fi
    fi
    
    # Submit login request to server (No error checking yet)
    echo "Attempting to log you into the JetIB server..."
    notify "Attempting to log you into the JetIB server..."
    curl -s -A "$USER_AGENT" -F "targeturl=''" -F "submit=Logon" -F "username=$USERNAME" -F "password=$PASSWORD" -c cookies.txt https://$DOMAIN$LOGIN_PAGE > /dev/null
    notify "Verifying login..."
    echo "Verifying login..."
    
    # trap ctrl-c and call ctrl_c()
    trap ctrl_c INT 
    stty -echo # Turn off TTY echo
    displayed_notify=false
    while true
    do # Loop updating status page every minute until Ctrl-C is pressed
    status_page ; displayed_notify=true ; sleep 1m
    done

else
    echo "This Jetib login tool requires curl to be installed and in the PATH";
fi
