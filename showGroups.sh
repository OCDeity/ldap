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


function showFilteredGroups() {

    local label=$1
    local min_gid=$2    
    local max_gid=$3
    local base_dn=$4

    # Get the groups
    readarray -t groups < <(ldapGetGroups "$min_gid" "$max_gid" "$base_dn") 

    # Display the groups
    if [ ${#groups[@]} -gt 0 ]; then

        # Build up a string of tab delimited output.
        # We start with the headers:
        GROUP_DATA="GID\tGroup\n"
        GROUP_COUNT=0
        for group in "${groups[@]}"; do
        
            if [ -z "$group" ]; then
                continue
            fi
        
            # Look up the group's GID:
            result=$(ldapGetGroupID "$group" "$BASE_DN" 2>/dev/null) 
            verifyResult "$?" "$result"
            group_gid="$result"

            # Add the group's data to the string:
            GROUP_DATA+="${group_gid}\t${group}\n"

            GROUP_COUNT=$((GROUP_COUNT + 1))
        done

        echo ""
        echo "$label found in \"$base_dn\" ($GROUP_COUNT):"
        echo -e "$GROUP_DATA" | column -t
    fi
}

showFilteredGroups "System groups" 1 1999 "$BASE_DN"
showFilteredGroups "User groups" 2000 2999 "$BASE_DN"
showFilteredGroups "Service groups" 3000 3999 "$BASE_DN"

showFilteredGroups "LXC Mapped System Groups" $LXC_OFFSET $((LXC_OFFSET + 1999)) "$BASE_DN"
showFilteredGroups "LXC Mapped User Groups" $((LXC_OFFSET + 2000)) $((LXC_OFFSET + 2999)) "$BASE_DN"
showFilteredGroups "LXC Mapped Service Groups" $((LXC_OFFSET + 3000)) $((LXC_OFFSET + 3999)) "$BASE_DN"
