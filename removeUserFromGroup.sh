#!/bin/bash

source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Ask for the username
read -p "Username: " USERNAME
result=$(ldapUserExists "$USERNAME" "$BASE_DN")
if ! [ "$result" == "true" ]; then
    echo "The user ${USERNAME} was not found"
    exit 0
fi

# Ask for the group name
read -p "Group: " group_name
GROUP_DN=$(ldapGetGroupDN "$group_name" "$BASE_DN")
if ! [ -n "$GROUP_DN" ]; then
    echo "The group \"$group_name\" was not found."
    exit 0
fi

# Check to see if the user is already a member of the group
result=$(ldapIsMember "$group_name" "$USERNAME" "$BASE_DN")
if ! [ "$result" == "true" ]; then
    echo "The user \"$USERNAME\" is not part of the group \"$group_name\""
    exit 0
fi

# Create a temporary file with a unique name
temp_file=$(mktemp)

# Export all of the variables we've collected and use them for templating
export BASE_DN USERNAME GROUP_DN
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/RemoveUserFromGroup.txt")
envsubst < "$TEMPLATE_FILE" > "$temp_file"

# Attempt to execute the modification in the .ldiff file we just constructed:
ldapModify "$temp_file" "$BASE_DN"
