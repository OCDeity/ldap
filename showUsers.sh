#!/bin/bash

REQUIRED_PARAMS=()
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


readarray -t users < <(ldapGetUsers "users" "$BASE_DN")

echo "Users found in \"$BASE_DN\":"
if [ ${#users[@]} -gt 0 ]; then
    USER_DATA="UID\tGID\tUsername\n"
    for user in "${users[@]}"; do
        result=$(ldapGetUserID "$user" "$BASE_DN" 2>/dev/null)
        verifyResult "$?" "$result"
        user_uid="$result"

        result=$(ldapGetUserGroupID "$user" "$BASE_DN" 2>/dev/null) 
        verifyResult "$?" "$result"
        user_gid="$result"

        USER_DATA+="${user_uid}\t${user_gid}\t${user}\n"
    done

    echo -e "$USER_DATA" | column -t
else
    echo "No users found"
fi

echo ""

readarray -t service_users < <(ldapGetUsers "services" $BASE_DN)

if [ ${#service_users[@]} -gt 0 ]; then
    SERVICE_DATA="UID\tGID\tUsername\n"
    echo "Service users found in \"$BASE_DN\":"
    for service_user in "${service_users[@]}"; do
        result=$(ldapGetUserID "$service_user" "$BASE_DN" 2>/dev/null)
        verifyResult "$?" "$result"
        user_uid="$result"

        result=$(ldapGetUserGroupID "$service_user" "$BASE_DN" 2>/dev/null) 
        verifyResult "$?" "$result"
        user_gid="$result"

        SERVICE_DATA+="${user_uid}\t${user_gid}\t${service_user}\n"
    done

    echo -e "$SERVICE_DATA" | column -t
else
    echo "No service users found"
fi

