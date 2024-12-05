#!/bin/bash

REQUIRED_PARAMS=()
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


showFilteredUsers() {

    local label=$1
    local ou_name=$2
    local min_uid=$3
    local max_uid=$4
    local base_dn=$5


    # Get our array of users:
    readarray -t users < <(ldapGetUsers "$ou_name" $min_uid $max_uid "$base_dn")

    if [ ${#users[@]} -gt 0 ]; then

        # Build up a string of tab delimited output.
        # We start with the headers:
        USER_DATA="UID\tGID\tUsername\n"
        USER_COUNT=0
        for user in "${users[@]}"; do

            if [ -z "$user" ]; then
                continue
            fi
        
            # Look up the user's UID:
            result=$(ldapGetUserID "$user" "$BASE_DN" 2>/dev/null)
            verifyResult "$?" "$result"
            user_uid="$result"


            result=$(ldapGetUserGroupID "$user" "$BASE_DN" 2>/dev/null) 
            verifyResult "$?" "$result"
            user_gid="$result"


            USER_DATA+="${user_uid}\t${user_gid}\t${user}\n"

            USER_COUNT=$((USER_COUNT + 1))
        done

        echo ""
        echo "$label found in dn: \"ou=$ou_name,$base_dn\" ($USER_COUNT):"
        echo -e "$USER_DATA" | column -t
    fi
}

showFilteredUsers "Users" "users" 2000 2999 "$BASE_DN"
showFilteredUsers "Services" "services" 3000 3999 "$BASE_DN"
showFilteredUsers "LXC Mapped Users" "users" $LXC_OFFSET $((LXC_OFFSET + 9999)) "$BASE_DN"
showFilteredUsers "LXC Mapped Services" "services" $LXC_OFFSET $((LXC_OFFSET + 9999)) "$BASE_DN"
echo ""
exit 0
