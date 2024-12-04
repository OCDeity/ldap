#!/bin/bash

REQUIRED_PARAMS=()
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

MIN_UID=2000
MAX_UID=2999

# Get our array of users:
readarray -t users < <(ldapGetUsers "users" $MIN_UID $MAX_UID "$BASE_DN")

if [ ${#users[@]} -gt 0 ]; then

    # Build up a string of tab delimited output.
    /root/ldap/templates# We start with the headers:
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
    echo "Users found in \"$BASE_DN\" ($USER_COUNT):"
    echo -e "$USER_DATA" | column -t
fi


MIN_UID=3000
MAX_UID=3999

# Get our array of service users:
readarray -t service_users < <(ldapGetUsers "services" $MIN_UID $MAX_UID "$BASE_DN")

if [ ${#service_users[@]} -gt 0 ]; then

    # Build up a string of tab delimited output.
    # We start with the headers:
    SERVICE_DATA="UID\tGID\tUsername\n"
    USER_COUNT=0
    for service_user in "${service_users[@]}"; do

        if [ -z "$service_user" ]; then
            continue
        fi

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

        USER_COUNT=$((USER_COUNT + 1))
    done

    echo ""
    echo "Service users found in \"$BASE_DN\" ($USER_COUNT):"
    echo -e "$SERVICE_DATA" | column -t
fi



MIN_UID=$LXC_OFFSET
MAX_UID=$((LXC_OFFSET + 9999))

# Get our array of users:
readarray -t users < <(ldapGetUsers "users" $MIN_UID $MAX_UID "$BASE_DN")

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
    echo "Mapped LXC Users found in \"$BASE_DN\" ($USER_COUNT):"
    echo -e "$USER_DATA" | column -t
fi

MIN_UID=$LXC_OFFSET
MAX_UID=$((LXC_OFFSET + 9999))

# Get our array of users:
readarray -t users < <(ldapGetUsers "services" $MIN_UID $MAX_UID "$BASE_DN")

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
    echo "Mapped LXC Services found in \"$BASE_DN\" ($USER_COUNT):"
    echo -e "$USER_DATA" | column -t
fi