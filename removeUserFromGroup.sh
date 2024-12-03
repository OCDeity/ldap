#!/bin/bash

REQUIRED_PARAMS=("USERNAME" "GROUPNAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

echo "Remove User from Group"

# If we don't have a username, ask for one
if [ -z "$USERNAME" ]; then
    read -p "  Username: " USERNAME
else
    echo "  Username: $USERNAME"
fi

result=$(ldapUserExists "$USERNAME" "$BASE_DN")
if ! [ "$result" == "true" ]; then
    echo "  User \"${USERNAME}\" not found!"
    exit 0
fi

# Ask for the group name if we don't have it
if [ -z "$GROUPNAME" ]; then
    read -p "  Group: " GROUPNAME
else
    echo "  Group: $GROUPNAME"
fi

GROUP_DN=$(ldapGetGroupDN "$GROUPNAME" "$BASE_DN")
if ! [ -n "$GROUP_DN" ]; then
    echo "  Group \"$GROUPNAME\" not found!"
    exit 0
fi

# Check to see if the user is already a member of the group
result=$(ldapIsMember "$GROUPNAME" "$USERNAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

if ! [ "$result" == "true" ]; then
    echo "  User \"$USERNAME\" not in \"$GROUPNAME\""
    exit 0
fi

# Create a temporary file with a unique name
temp_file=$(mktemp)
echo "  Temp ldif: $temp_file"

# Export all of the variables we've collected and use them for templating
export BASE_DN USERNAME GROUP_DN
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/RemoveUserFromGroup.txt")
envsubst < "$TEMPLATE_FILE" > "$temp_file"

getLDAPPassword LDAP_PASSWORD

# Attempt to execute the modification in the .ldiff file we just constructed:
result=$(ldapModify "$temp_file" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
verifyResult "$?" "$result"

echo "  User \"$USERNAME\" removed from group \"$GROUPNAME\""
