#! /bin/bash

REQUIRED_PARAMS=()
OPTIONAL_PARAMS=("BASE_DN")

# Load configuration and LDAP library
source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Get the groups
readarray -t groups < <(ldapGetGroups "$BASE_DN")


# Display the groups
if [ ${#groups[@]} -gt 0 ]; then

    # Build up a string of tab delimited output.
    # We start with the headers:
    GROUP_DATA="GID\tGroup\n"
    for group in "${groups[@]}"; do
    
        # Look up the group's GID:
        result=$(ldapGetGroupID "$group" "$BASE_DN" 2>/dev/null) 
        verifyResult "$?" "$result"
        group_gid="$result"

        # Add the group's data to the string:
        GROUP_DATA+="${group_gid}\t${group}\n"
    done

    echo "Groups found in \"$BASE_DN\":"
    echo -e "$GROUP_DATA" | column -t
fi