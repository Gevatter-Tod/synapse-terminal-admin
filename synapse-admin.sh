#!/bin/bash

# This script aims to simplify the administration of the Matrix-synapse server while working in the terminal.
# In general it interacts with the server through the official API via curl.


# This function generates a configuration file to store the server address and the admin token.
function generate_config {

    echo "No config file was found. Starting configuration (press Ctrl-C for cancle)"
    read -e -p "Sever Adress (without \"http(s)://\"): " SERVER_ADDRESS
    read -e -p "Admin Token: " ADMINTOKEN
    mkdir ~/.synapse-admin
    echo "server: $SERVER_ADDRESS;" > ~/.synapse-admin/synapse-admin.conf
    echo "admintoken: $ADMINTOKEN;" >> ~/.synapse-admin/synapse-admin.conf
    echo "config generated"

}


#Reading the config file
function read_config {

while read y
do
if [[ "$y" == *"server"* ]]
then SERVER_ADDRESS=$(awk '{ sub(/.*server: /, ""); sub(/;.*/, ""); print }' <<< "$y")
elif [[ "$y" == *"admintoken"* ]]
then ADMINTOKEN=$(awk '{ sub(/.*admintoken: /, ""); sub(/;.*/, ""); print  }' <<< "$y")
else echo "no server found: $y"
fi
done < ~/.synapse-admin/synapse-admin.conf

}

# Display general help

function help {

echo ""
echo "-- synapse-admin is a cmd script using the official matrix-synapse API for administration --  "
echo "" 
echo "Usage:"
echo "synapse-admin.sh [command]"
echo ""
echo "available commands"
echo "  help - displays this section"
echo "  userlist - queries usernames and caches them locally"
echo "  server - displays the server version"
echo "  user - display and manipulate individaul accounts"
echo ""

}

# Displaying help for the user subsection
function help_user {

echo ""
echo "Usage:"
echo "Query details of the user: synapse-admin.sh user [username]"
echo "Change user settings: synapse-admin.sh user [username] set [options] <value>"
echo ""
echo "Available options:"
echo "  displayname <value> - change the display name to the <value>"
echo "  media               - Display media list"
echo "  password            - change the password"

}

# Query the list of users
function userlist {

    echo "Query usernames..."
    echo ""
    local TEMPLIST=$(curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v2/users?from=0")
    echo "usernames:"

    for y in $TEMPLIST  
    do
    jq '.users[] | {name: .name}' <<< "$y" | sed "s/{//g;s/}//g;/^$/d;s/\"name\"://g;s/\"//g"  
    done    
}

# Function to check and repair the formating of the user name.
function fix_userid {

M_USER=$1
if ! [[ "$M_USER" == *"@"* ]]
then M_USER="@$M_USER"
fi
if ! [[ "$M_USER" == *"$SERVER_ADDRESS"* ]]
then M_USER="$M_USER:$SERVER_ADDRESS"
fi

}

# Function to Query details of a single user
function user_get {
if [ -z "$M_USER" ]
then help_user; return
fi
printf "\nQuery user: $M_USER \n"
curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$M_USER" | jq

}

# Function to query User media
function user_media {

echo "user $M_USER Media:"
echo ""
local TEMPLIST=$(curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/users/$M_USER/media")
jq '.media[] | {media_id: .media_id, media_type: .media_type, quarantined_by: .quarantined_by, created_ts: .created_ts}' <<< "$TEMPLIST" | sed "s/{//g;s/}//g;/^$/d;s/\"name\"://g;s/\"//g"  

}

#This function triggers changes to user accounts
#TODO: #1 This needs a check for "new user generation", so that no new users are generated accidentially
function user_change {
echo "Identified user $M_USER..."
if [ -z "$2" ]; then help_user; return
elif [ "$2" = "displayname" ]
    then echo "setting displayname to $3"
    curl -s --header "Authorization: Bearer $ADMINTOKEN" -X PUT "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$M_USER" -d '{ "displayname": "'"$3"'" }' | jq
#Section to change password
elif [ "$2" = "password" ]
    then echo "this will change the password of the user. All devices are logged out! Continue?"
    read -p "[y/n]: " yn
        case $yn in
            [Yy]*) read -s -p "please enter password: " M_PW;
            echo "";
            read -s -p "please repeate password: " M_PW2;
            echo ""
            if [ $M_PW = $M_PW2 ];
            then curl -s --header "Authorization: Bearer $ADMINTOKEN" -X PUT "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$M_USER" -d '{ "password": "'"$M_PW"'" }' | jq;
            return;
            else echo "PW dont match, aborting"; return;
            fi
            echo "this is the password: $M_PW"
            echo "yn"
            ;;

            [Nn]) echo "Aborted" ; return ;;
            *) echo "wrong input"; return;;
        esac
fi

}

# This function queries the server Version
function server {

   curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/server_version" | jq '.'
}


# Start of the script

# Testing if there is a config file available.
if test -f ~/.synapse-admin/synapse-admin.conf
then
# Reading config
    echo "synapse-admin.conf found"
    read_config
# Executing command
    if [ -z "$1" ]  || [ "$1" = "help" ]
    then help
    elif [ "$1" = "userlist" ]; then userlist
    elif [ "$1" = "server" ]; then server
    elif [ "$1" = "user" ]
        then
        if ! [ -z "$2" ]
        then fix_userid "$2"
        fi
        if [ "$3" = "set" ]; then user_change "$2" "$4" "$5"
        elif [ "$3" = "media" ]; then user_media "$2"
        else user_get "$2"
        fi
    else echo "command unkown"
    fi
# If no config available, start configuration function
else
    generate_config
fi


