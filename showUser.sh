#!/bin/bash

REQUIRED_PARAMS=("USERNAME")
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Ask for the username if not provided
if [ -z "$USERNAME" ]; then
    read -p "Username: " username
fi

# Display the user
ldapsearch -x -LLL -b "$BASE_DN" "(&(objectClass=posixAccount)(uid=$USERNAME))" 2>/dev/null
