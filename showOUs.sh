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
    while IFS= read -r org_unit; do
        count=$(ldapGetOUMemberCount "$org_unit" "$BASE_DN")
        verifyResult "$?" "$count"

        OU_DATA+="${count}\t${org_unit}\n"
    done <<< "$result"

    echo "Organizational Units found in \"$BASE_DN\":"
    echo -e "$OU_DATA" | column -t
fi

