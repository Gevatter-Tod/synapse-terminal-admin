#!/bin/bash

function generate_config {

    echo "No config file was found. Starting configuration (press Ctrl-C for cancle)"
    read -e -p "Sever Adress (URL): " SERVER_URL
    read -e -p "Admin Token: " ADMINTOKEN
    echo $SERVER_URL and $ADMINTOKEN
    echo "server: $SERVER_URL" > synapse-admin.conf
    echo "admintoke: $ADMINTOKEN" >> synapse-admin.conf

}

function read_config {

while read y
do
if [[ "$y" == *"server"* ]]
then echo "server is $y"
elif [[ "$y" == *"admintoken"* ]]
then echo "admintoken $y"
else echo "no server found: $y"
fi
done < synapse-admin.conf

}

function help {

    echo ""
    echo "-- synapse-admin is a cmd script using the official matrix-synapse API for administration --  "
    echo "" 
    echo "Usage:"
    echo "synapse-admin.sh [command]"
    echo ""
    echo "available commands"
    echo "  help  displays this section"
    echo "  users queries usernames and caches them locally"
    echo ""
}

function users {

    echo "Query usernames..."
    curl --header "Authorization: Bearer syt_cm9zZQ_gRgBVBbJZvGEiXleclGM_3SVQaX" "https://m.rosanelli.at/_synapse/admin/v2/users?from=0&limit=10&guests=false" | jq
}


if test -f synapse-admin.conf
then
    echo "synapse-admin.conf found"
    read_config
    if [ -z "$1" ]  || [ "$1" = "help" ]
    then help
    elif [ "$1" = "users" ]
    then users
    else echo "command unkown"
    fi
else
    generate_config
fi


