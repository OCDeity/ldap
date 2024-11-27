#!/bin/bash

# Include the ldaplib.sh library
source ldaplib.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get the group name
read -p "Group: " group_name

# Get the base DN
BASE_DN=$(getBaseDN)

# Display the given group
ldapsearch -x -LLL -b "$BASE_DN" "(&(objectClass=posixGroup)(cn=$group_name))" 2>/dev/null
