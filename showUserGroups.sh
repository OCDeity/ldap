#!/bin/bash

# Include the ldaplib.sh library
source ldaplib.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Get the username
read -p "Username: " username

# Display the user's groups
ldapGetUserGroups "$username" "$BASE_DN"
