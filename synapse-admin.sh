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
echo "  help        - displays this section"
echo "  server      - displays the server version and status of background updates"
echo "  userlist    - queries usernames and caches them locally"
echo "  user        - display and manipulate individual accounts"
echo "  event       - list events"
echo "  roomlist    - lists all rooms on the server"
echo "  room        - display and manipulate individual rooms"
echo ""

}

# Displaying help for the user subsection
function help_user {

echo ""
echo "Usage:"
echo "Query details of the user: synapse-admin.sh user [username] [options]"
echo "Available options:"
echo "  media                  - Display media list"
echo "  create                 - Create a new user with the given [username]"
echo "  set                    - Apply changes to the user:"
echo "    displayname <value>  - Change display Name"
echo "    password             - Change the Users Password"
echo "  deactivate             - Deactivates the user"
echo ""

}


# Displaying help for the room subsection
function help_room {

echo ""
echo "Usage:"
echo "Query details of the room: synapse-admin.sh room ['room_id' / roomname]"
echo "Change room settings: synapse-admin.sh user ['room_id' / roomname] [options] <value>"
echo "Important! you need to put room_id in ' '. Bash otherwise throws an error as roomnames start with '"!"'"
echo ""
echo "Available options:"
echo "  members     - displays member list for room_id"
echo "  state       - lists room state"

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
function user_change {
echo "Identified user $M_USER..."
USER_EXISTING=$(curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$M_USER" | jq '{errcode: .errcode}' | sed "s/{//g;s/}//g;/^$/d;s/\"name\"://g;s/\"//g")
if [[ "$USER_EXISTING" = *"M_NOT_FOUND"* ]]
    then echo ""; echo "Username not found, aborting"; echo ""; return
fi
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


# Function to create a new User
function user_create {


USER_EXISTING=$(curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$M_USER")
if [[ "$USER_EXISTING" = *"M_NOT_FOUND"* ]]
    then echo "Creating User $M_USER"
        read -p "Enter the Displayname for the user $M_USER: " displayname
        read -sp "Enter the password: " password
        echo "Creating User..."
        curl -s --header "Authorization: Bearer $ADMINTOKEN" -X PUT "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$M_USER" -d '{"password": "'"$password"'", "displayname": "'"$displayname"'", "admin": false}'
    else echo "User $M_USER already existing"; return
fi
}

#Function to deactivate a user
function user_deactivate {
USER_EXISTING=$(curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$M_USER")
if [[ "$USER_EXISTING" = *"M_NOT_FOUND"* ]]
    then echo "Username not found, aborting"; echo ""; return
fi
echo "this will deactivate User $M_USER. Continue?"
    read -p "[y/n]: " yn
        case $yn in
            [Yy]*) echo "deactivating..."; curl -s --header "Authorization: Bearer $ADMINTOKEN" -X POST "https://$SERVER_ADDRESS/_synapse/admin/v1/deactivate/$M_USER"; return;;
            [Nn]) echo "Aborted" ; return ;;
            *) echo "wrong input"; return;;
        esac

}



# This function queries the server Version
function server {

    case $1 in
    enable-updates) 
    # TODO: #2 Enabling and disabling background updates runs into error. Functionality has been disabled.  
    # echo "Enabling background updates"
    # curl -s --header "Authorization: Bearer $ADMINTOKEN" -X PUT "https://$SERVER_ADDRESS/_synapse/admin/v1/background_updates/start_job" -d '{ "job_name": "populate_stats_process_rooms" }'
    return;;
    disable-updates)
    # echo "Disabling Background updates"
    # curl -s --header "Authorization: Bearer $ADMINTOKEN" -X PUT "https://$SERVER_ADDRESS/_synapse/admin/v1/background_updates/enabled" -d '{ "enabled": false }'
    return;;
    *)
    # echo "To enable/diable database background updates run ./synapse-admin.sh server enable-updates/disable-updates"
    echo ""
    echo "Server version"
    curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/server_version" | jq '.'
    echo "Status background updates"
    curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/background_updates/status" | jq '.'
    esac
}


# Distplays list of events
function event_report {

echo "event report"
curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/event_reports?from=0" | jq '.'

}


# Lists rooms
function roomlist {

echo "List of rooms"
curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/rooms" | jq '.'

}

#function to get details from a room
function room_get  {

if [ ${1:0:1} = '!' ]
then
    case $2 in
    members | state)
        echo "Listing $2 for room $1"
        curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/rooms/$1/$2" | jq '.'
        return;;
    *)
        echo "room details for room_id $1"
        curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/rooms/$1" | jq '.';;
    esac
else
    echo "Seraching for room containing $1"
    curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/rooms?search_term=$1" | jq '.'
fi

}


# Start of the script

# Testing if there is a config file available.
if test -f ~/.synapse-admin/synapse-admin.conf
then
# Reading config
    echo "synapse-admin.conf found"
    echo ""
    read_config
# Executing command
    if [ -z "$1" ]  || [ "$1" = "help" ]
    then help
    elif [ "$1" = "userlist" ]; then userlist
    elif [ "$1" = "server" ]; then server $2
    elif [ "$1" = "event" ]; then event_report
    elif [ "$1" = "roomlist" ]; then roomlist
    elif [ "$1" = "room" ]; 
        then 
        if ! [ -z "$2" ]
        then room_get $2 $3
        else help_room
        fi
    elif [ "$1" = "user" ]
        then
        if ! [ -z "$2" ]
        then fix_userid "$2"
        fi
        if [ "$3" = "set" ]; then user_change "$2" "$4" "$5"
        elif [ "$3" = "media" ]; then user_media "$2"
        elif [ "$3" = "create" ]; then user_create "$2"
        elif [ "$3" = "deactivate" ]; then user_deactivate "$2"
        else user_get "$2"
        fi
    else echo "command unkown"
    fi
# If no config available, start configuration function
else
    generate_config
fi


