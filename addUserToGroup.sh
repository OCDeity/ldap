#!/bin/bash

REQUIRED_PARAMS=("USERNAME" "GROUPNAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "TEMPLATE_PATH")

# Include our settings:
source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi




# Ask for the username if 
if [ -z "$USERNAME" ]; then
    read -p "Username: " USERNAME
fi

# Check to see if the user exists:
result=$(ldapUserExists "$USERNAME" "$BASE_DN")
if ! [ "$result" == "true" ]; then
    echo "The user ${USERNAME} was not found"
    exit 0
fi


# Ask for the group name if it's not already set:
if [ -z "$GROUPNAME" ]; then
    read -p "Group: " GROUPNAME
fi

# Get the group DN:
GROUP_DN=$(ldapGetGroupDN "$GROUPNAME" "$BASE_DN")
if ! [ -n "$GROUP_DN" ]; then
    echo "The group \"$GROUPNAME\" was not found."
    exit 0
fi

# Check to see if the user is already a member of the group:
result=$(ldapIsMember "$GROUPNAME" "$USERNAME" "$BASE_DN")
if [ "$result" == "true" ]; then
    echo "The user \"$USERNAME\" is already part of the group \"$GROUPNAME\""
    exit 0
fi


# Create a temporary file with a unique name
temp_file=$(mktemp)

# Export all of the variables we've collected and use them for templating
export BASE_DN USERNAME GROUP_DN
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/AddUserToGroup.txt")
envsubst < "$TEMPLATE_FILE" > "$temp_file"

# Attempt to execute the modification in the .ldiff file we just constructed:
ldapModify "$temp_file" "$BASE_DN" "$LDAP_PASSWORD"
