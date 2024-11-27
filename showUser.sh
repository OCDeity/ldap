#!/bin/bash

# Include the ldaplib.sh library
source ldaplib.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Ask for the username
read -p "Username: " username

# Display the user
ldapsearch -x -LLL -b "$BASE_DN" "(&(objectClass=posixAccount)(uid=$username))" 2>/dev/null
