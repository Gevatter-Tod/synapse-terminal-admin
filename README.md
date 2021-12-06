# synapse-terminal-admin
The Synapse server for Matrix does use an Admin API that is a bit cumbersome to handle in the terminal. It requires manual insertion of access tokens and quite long cURL requests which are hard to remember.
This script aims to do the copying and remembering part for you. It provides standard /bin/bash type commands and transfers them into cURL API requests as described in the official docu (https://matrix-org.github.io/synapse/latest/usage/administration/admin_api/)

It is in Alpha stage and not all commands are implemented. It currently does allow you to store the server config, query for user names as well as change user passwords.

I plan to implement all the other functions in the near future.


**Installation:**
- Download the "synapse-admin.sh" script
- Make it executable (e.g. with "chmod 755 ./synapse-admin.sh" )
- On the first run, the script will ask for the server name and the admin access token. Both information will stay on your PC an will be stored in "~/.synapse-admin/synapse-admin.conf"

**Useage**

Just run "./synapse-admin.sh" to see a description of implemented commands