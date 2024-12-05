#!/bin/bash

REQUIRED_PARAMS=()
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get the OUs
result=$(ldapGetOUs "$BASE_DN")
verifyResult "$?" "$result"

if [ ${#result[@]} -gt 0 ]; then

    # Build up a string of tab delimited output.
    # We start with the headers:
    OU_DATA="Entities\tOrganizational_Unit\n"
    OU_COUNT=0
    while IFS= read -r org_unit; do

        # Skip empty lines:
        if [ -z "$org_unit" ]; then
            continue
        fi

        # Get the count of members in the OU:
        count=$(ldapGetOUMemberCount "$org_unit" "$BASE_DN")
        verifyResult "$?" "$count"

        # The count includes itself, so we need to subtract one:
        count=$(($count - 1))

        OU_DATA+="${count}\t${org_unit}\n"
        OU_COUNT=$((OU_COUNT + 1))
    done <<< "$result"

    # Only show the data if we have any:
    if [ $OU_COUNT -gt 0 ]; then
        echo "Organizational Units found in \"$BASE_DN\" ($OU_COUNT):"
        echo -e "$OU_DATA" | column -t
    fi
fi

