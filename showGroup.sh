#!/bin/bash

REQUIRED_PARAMS=("GROUPNAME")
OPTIONAL_PARAMS=("BASE_DN")

# Include the ldaplib.sh library
source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get the group name if not provided:
if [ -z "$GROUPNAME" ]; then
    read -p "Group: " group_name
fi


# Display the given group
ldapsearch -x -LLL -b "$BASE_DN" "(&(objectClass=posixGroup)(cn=$GROUPNAME))" 2>/dev/null
