#!/bin/bash

source ./ldaplib.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get the group name
read -p "OU Name: " ou_name


# Display the given group
ldapsearch -x -LLL -b "$BASE_DN" "(&(objectClass=organizationalUnit)(ou=$ou_name))" 2>/dev/null

ldapGetOUMembers "$ou_name" "$BASE_DN"