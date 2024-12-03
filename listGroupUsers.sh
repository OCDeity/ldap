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
result=$(ldapGetMembers "$GROUPNAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

# Only if we've got a user list, display it:
if [ ${#result[@]} -gt 0 ]; then

    # Build up a string of tab delimited output.
    # We start with the headers:
    USER_DATA="UID\tUsername\n"

    # look up the UID for each user and add it to GROUP_DATA
    while IFS= read -r group_user; do
        user_id=$(ldapGetUserID "$group_user" "$BASE_DN")
        verifyResult "$?" "$user_id"

        USER_DATA+="${user_id}\t${group_user}\n"
    done <<< "$result"

    echo "Users found in group \"$GROUPNAME\":"
    echo -e "$USER_DATA" | column -t
fi
