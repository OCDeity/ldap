#!/bin/bash

REQUIRED_PARAMS=("GROUPNAME")
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get the group name if not provided 
if [ -z "$GROUPNAME" ]; then
    read -p "Group: " GROUPNAME
fi

# Display the group members
ldapGetMembers "$GROUPNAME" "$BASE_DN"
