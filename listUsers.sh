#!/bin/bash

REQUIRED_PARAMS=()
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get our array of users:
readarray -t users < <(ldapGetUsers "users" "$BASE_DN")

if [ ${#users[@]} -gt 0 ]; then

    # Build up a string of tab delimited output.
    # We start with the headers:
    USER_DATA="UID\tGID\tUsername\n"
    for user in "${users[@]}"; do
    
        # Look up the user's UID:
        result=$(ldapGetUserID "$user" "$BASE_DN" 2>/dev/null)
        verifyResult "$?" "$result"
        user_uid="$result"


        result=$(ldapGetUserGroupID "$user" "$BASE_DN" 2>/dev/null) 
        verifyResult "$?" "$result"
        user_gid="$result"


        USER_DATA+="${user_uid}\t${user_gid}\t${user}\n"
    done

    echo "Users found in \"$BASE_DN\":"
    echo -e "$USER_DATA" | column -t
fi

echo ""


# Get our array of service users:
readarray -t service_users < <(ldapGetUsers "services" $BASE_DN)

if [ ${#service_users[@]} -gt 0 ]; then

    # Build up a string of tab delimited output.
    # We start with the headers:
    SERVICE_DATA="UID\tGID\tUsername\n"
    for service_user in "${service_users[@]}"; do

        # Look up the service user's UID:
        result=$(ldapGetUserID "$service_user" "$BASE_DN" 2>/dev/null)
        verifyResult "$?" "$result"
        user_uid="$result"

        # Look up the service user's GID:
        result=$(ldapGetUserGroupID "$service_user" "$BASE_DN" 2>/dev/null) 
        verifyResult "$?" "$result"
        user_gid="$result"

        # Add the service user's data to the string:
        SERVICE_DATA+="${user_uid}\t${user_gid}\t${service_user}\n"
    done

    echo "Service users found in \"$BASE_DN\":"
    echo -e "$SERVICE_DATA" | column -t
fi

