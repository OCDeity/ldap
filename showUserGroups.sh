#!/bin/bash

REQUIRED_PARAMS=("USERNAME")
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh



# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Get the username if not provided
if [ -z "$USERNAME" ]; then
    read -p "Username: " USERNAME
fi

# Make sure the user exists
result=$(ldapUserExists "$USERNAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

if [ "$result" != "true" ]; then
    echo "User \"$USERNAME\" not found in \"$BASE_DN\""
    exit 1
fi

# Display the user's groups
result=$(ldapGetUserGroups "$USERNAME" "$BASE_DN")
verifyResult "$?" "$result"

# Only if we've got a group list, display it:
if [ ${#result[@]} -gt 0 ]; then

    # Build up a string of tab delimited output.
    # We start with the headers:
    GROUP_DATA="GID\tGroup\n"

    # look up the GID for each group and add it to GROUP_DATA
    while IFS= read -r user_group; do
        group_id=$(ldapGetGroupID "$user_group" "$BASE_DN")
        verifyResult "$?" "$group_id"

        GROUP_DATA+="${group_id}\t${user_group}\n"
    done <<< "$result"

    echo "Groups found for user \"$USERNAME\":"
    echo -e "$GROUP_DATA" | column -t
fi

