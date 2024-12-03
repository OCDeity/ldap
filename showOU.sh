#!/bin/bash

REQUIRED_PARAMS=("OU_NAME")
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get the group name
if [ -z "$OU_NAME" ]; then
    read -p "OU Name: " OU_NAME
fi


# Display the given group
result=$(ldapGetOUDetail "$OU_NAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

echo "$result"


# Get the members of the OU
result=$(ldapGetOUMembers "$OU_NAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

if [ -n "$result" ]; then
	echo ""
	echo "Members:"
	echo "$result"
fi
