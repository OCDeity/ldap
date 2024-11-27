#!/bin/bash

REQUIRED_PARAMS=("USERNAME")
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh



# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Get the username if not provided
if [ -z "$USERNAME" ]; then
    read -p "Username: " USERNAME
fi

# Display the user's groups
ldapGetUserGroups "$USERNAME" "$BASE_DN"
