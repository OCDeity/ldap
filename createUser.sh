#!/bin/bash

REQUIRED_PARAMS=("USERNAME" "PW_HASH" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN"  "NEW_UID" "NEW_GID" "TEMPLATE_PATH" "USER_LDIF_PATH")

# Include our settings:
source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Make sure that the output path exists..
if [ ! -d "${USER_LDIF_PATH}" ]; then
    echo "Creating ${USER_LDIF_PATH}"
    mkdir -p "${USER_LDIF_PATH}"
fi





# Read in the new username if it's not already set:
if [ -z "$USERNAME" ]; then
    read -p "Username: " USERNAME
fi


result=$(ldapUserExists "$USERNAME" "$BASE_DN")
if [ "$result" != "true" ]; then
    echo "Creating user ${USERNAME}"


    # Work out the path to the user .ldif
    USER_LDIF=$(realpath "${USER_LDIF_PATH}/${USERNAME}.ldif")


    # Get the next available UID if it's not already set:   
    if [ -z "$NEW_UID" ]; then
        NEW_UID=$(ldapGetNextUID "$BASE_DN")
    fi
    result=$(ldapUserIdExists "$NEW_UID" "$BASE_DN")
    if [ "$result" == "true" ]; then
        echo "ERROR: User ID ${NEW_UID} already exists"
        exit 1
    fi

    # If not set by the caller, use the UID as the GID:
    if [ -z "$NEW_GID" ]; then
        NEW_GID="$NEW_UID"
    fi

    # We've got a group ID.  Check to see if it exists. 
    # If it does, that may be OK.  We need to verify 
    # that the username and that group name match.
    result=$(ldapGroupIdExists "$NEW_GID" "$BASE_DN")
    if [ "$result" == "true" ]; then

        result=$(ldapGetGroupName "$NEW_GID" "$BASE_DN" 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to get group name for ID ${NEW_GID}"
            echo "$result"
            exit 1
        fi

        if [ "$result" != "$USERNAME" ]; then
            echo "ERROR: Group ID ${NEW_GID} already exists"
            echo "  Expected: ${USERNAME}"
            echo "  Found:    ${result}"
            exit 1
        fi
    fi


    # We should be all good on UID & GID.  Report them:
    echo "  UID: ${NEW_UID}"
    echo "  GID: ${NEW_GID}"


    # If we've no password hash, ask for the pw & hash it.
    if [ -z "$PW_HASH" ]; then
        read -s -p "  Passowrd: " PASSWORD

        # Clear the line.  Note we don't really care if the 
        # username was too long for this to erase it all.
        echo -ne "\r                                   \r"

        # In the end, this is what we really needed.
        PW_HASH=$(slappasswd -s "$PASSWORD")
    fi
    echo "  PW_HASH: ${PW_HASH}"


    # Get the LDAP Admin Password if we don't already have it.
    getLDAPPassword LDAP_PASSWORD


    # Exporting variables is necessary for the envsubst command to work
    export BASE_DN USERNAME PW_HASH NEW_UID NEW_GID
    TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/UserTemplate.txt")
    envsubst < "${TEMPLATE_FILE}" > "${USER_LDIF}"

    # Import the new user into LDAP
    result=$(ldapAdd "$USER_LDIF" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Failed to create user ${USERNAME}"
        echo "$result"
        exit 1
    fi
    echo "  Created user ${USERNAME}"
else
    echo "User ${USERNAME} exists"
    result=$(ldapGetUserID "$USERNAME" "$BASE_DN" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to get user ID for ${USERNAME}"
        echo "$result"
        exit 1
    fi

    # If the caller set a new UID, make sure it matches
    # what we read from LDAP.
    if ! [ -z "$NEW_UID" ]; then
        if [ "$result" != "$NEW_UID" ]; then
            echo "ERROR: User ID mismatch for ${USERNAME}"
            echo "  Expected: ${NEW_UID}"
            echo "  Read:     ${result}"
            exit 1
        fi
    fi
    NEW_UID="$result"
    echo "  UID: ${NEW_UID}"

    
    # Now for the group ID.  See what is set on the LDAP user.
    result=$(ldapGetUserGroupID "$USERNAME" "$BASE_DN" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to get group ID for ${USERNAME}"
        echo "$result"
        exit 1
    fi

    # If the caller set a new GID, make sure it matches
    # what we read from LDAP.
    if ! [ -z "$NEW_GID" ]; then
        if [ "$result" != "$NEW_GID" ]; then
            echo "ERROR: Group ID mismatch for ${USERNAME}"
            echo "  Expected: ${NEW_GID}"
            echo "  Found:    ${result}"
            exit 1
        fi
    fi
    NEW_GID="$result"
    echo "  GID: ${NEW_GID}"

    if ! [ -z "$PW_HASH" ]; then
        # Note that we could veify that the existing hash 
        # is what the caller provided.  That requires extra
        # permissions.  We'll skip it, at least for now.
        # It may be wise to skip it forever.
        echo "  PW_HASH: (not verified)"
    fi
fi


# Check to see if the user group exists.
result=$(ldapGroupExists "$USERNAME" "$BASE_DN" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to check if group ${USERNAME} exists"
    echo "$result"
    exit 1
fi

if [ "$result" != "true" ]; then
    echo "Creating group ${USERNAME}"

    # The group name is the same as the username:
    GROUPNAME="$USERNAME"

    echo "  GID: ${NEW_GID}"

    # Get the LDAP Admin Password if we don't already have it.
    getLDAPPassword LDAP_PASSWORD

    # Get the path to the user group .ldif
    USER_GROUP_LDIF=$(realpath "${USER_LDIF_PATH}/${USERNAME}-group.ldif")


    # Exporting variables is necessary for the envsubst command to work
    export BASE_DN GROUPNAME NEW_GID
    TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/GroupTemplate.txt")
    envsubst < "${TEMPLATE_FILE}" > "${USER_GROUP_LDIF}"

    # Import the new user group into LDAP
    resultlt=$(ldapAdd "$USER_GROUP_LDIF" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Failed to create group ${USERNAME}"
        echo "$result"
        exit 1
    fi
    echo "  Created group ${USERNAME}"
    
else
    echo "Group ${USERNAME} exists"

    # The user's group exists..  we need to make sure that
    # it has a GID that matches that of the user.
    result=$(ldapGetGroupID "$USERNAME" "$BASE_DN" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to get group ID for ${USERNAME}"
        echo "$result"
        exit 1
    fi

    # Make sure that the group ID matches our user's GID.
    if [ "$result" != "$NEW_GID" ]; then
        echo "ERROR: Group ID mismatch for ${USERNAME}"
        echo "  Expected: ${NEW_GID}"
        echo "  Found:    ${result}"
        exit 1
    fi

    echo "  GID: ${NEW_GID}"
fi

