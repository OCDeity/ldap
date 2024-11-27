#!/bin/bash

# Include the ldaplib.sh library
source ldaplib.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get the group name
read -p "Group: " group

# Display the group members
ldapGetMembers "$group" "$BASE_DN"
