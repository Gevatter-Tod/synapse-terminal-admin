#!/bin/bash

function generate_config {

    echo "No config file was found. Starting configuration (press Ctrl-C for cancle)"
    read -e -p "Sever Adress (without \"http(s)://\"): " SERVER_ADDRESS
    read -e -p "Admin Token: " ADMINTOKEN
    mkdir ~/.synapse-admin
    echo "server: $SERVER_ADDRESS;" > ~/.synapse-admin/synapse-admin.conf
    echo "admintoken: $ADMINTOKEN;" >> ~/.synapse-admin/synapse-admin.conf
    echo "config generated"

}

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

function help_user {

echo ""
echo "Usage:"
echo "Query details of the user: synapse-admin.sh user [username]"
echo "Change user settings: synapse-admin.sh user [username] set [options] <value>"
echo ""
echo "Available options"
echo "  displayname <value> - change the display name to the <value>"
#echo "  password - change the password"


}

function userlist {

    echo "Query usernames..."
    echo ""
    local TEMPLIST=$(curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v2/users?from=0")
    echo "Usernames:"

    for y in $TEMPLIST  
    do
    jq '.users[] | {name: .name}' <<< "$y" | sed "s/{//g;s/}//g;/^$/d;s/\"name\"://g;s/\"//g"  
    done    
}


function fix_userid {
USER=$1
if [ -z "$USER" ]
then help_user; return
elif ! [[ "$USER" == *"@"* ]]
then USER="@$USER"
fi
if ! [[ "$USER" == *"$SERVER_ADDRESS"* ]]
then USER="$USER:$SERVER_ADDRESS"
fi

}

function user_get {
if [ -z "$USER" ]
then help_user; return
fi
printf "\nQuery User: $USER \n"
curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$USER" | jq

}

function user_media {

echo "User $USER Media:"
echo ""
local TEMPLIST=$(curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/users/$USER/media")

for y in $TEMPLIST  
do
    jq '.media[3] | {media_id: .media_id, media_type: .media_type}' <<< "$TEMPLIST" | sed "s/{//g;s/}//g;/^$/d;s/\"name\"://g;s/\"//g"  
done  

}

function user_change {
echo "Identified User $USER..."
if [ -z "$2" ]; then help_user; return
elif [ "$2" = "displayname" ]
    then echo "setting displayname to $3"
    curl -s --header "Authorization: Bearer $ADMINTOKEN" -X PUT "https://$SERVER_ADDRESS/_synapse/admin/v2/users/$USER" -d '{ "displayname": "'"$3"'" }' | jq
fi

}

function server {

   curl -s --header "Authorization: Bearer $ADMINTOKEN" "https://$SERVER_ADDRESS/_synapse/admin/v1/server_version" | jq '.'
}

if test -f ~/.synapse-admin/synapse-admin.conf
then
# Reading config
    echo "synapse-admin.conf found"
    read_config
#Executing command
    if [ -z "$1" ]  || [ "$1" = "help" ]
    then help
    elif [ "$1" = "userlist" ]; then userlist
    elif [ "$1" = "server" ]; then server
    elif [ "$1" = "user" ]
        fix_userid "$2"
        then if [ "$3" = "set" ]; then user_change "$2" "$4" "$5"
        elif [ "$3" = "media" ]; then user_media "$2"
        else user_get "$2"
        fi
    else echo "command unkown"
    fi
else
    generate_config
fi


