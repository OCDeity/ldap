#!/bin/bash


REQUIRED_PARAMS=("GROUPNAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "NEW_GID" "TEMPLATE_PATH" "GROUP_LDIF_PATH")

# Include our settings:
source ./ldaplib.sh
source ./config.sh



# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Make sure that the output path exists..
if [ ! -d "${GROUP_LDIF_PATH}" ]; then
    echo "Creating ${GROUP_LDIF_PATH}"
    mkdir -p "${GROUP_LDIF_PATH}"
fi



# Ask for the group name if it's not already set:
if [ -z "$GROUPNAME" ]; then
    read -p "New Group Name: " GROUPNAME
fi




# Check to see if the user group exists.
result=$(ldapGroupExists "$GROUPNAME" "$BASE_DN" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to check if group ${GROUPNAME} exists"
    echo "$result"
    exit 1
fi

if [ "$result" != "true" ]; then
    echo "Creating group ${GROUPNAME}"

 
    # Get the next available GID if it's not already set:
    if [ -z "$NEW_GID" ]; then
        result=$(ldapGetNextGID "$BASE_DN" 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to get next GID"
            echo "$result"
            exit 1
        fi
        NEW_GID="$result"
    fi

    # Make sure that the group ID doesn't already exist.
    result=$(ldapGroupIdExists "$NEW_GID" "$BASE_DN" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "ERROR: Group ID ${NEW_GID} already exists"
        echo "$result"
        exit 1
    fi

    echo "  GID: ${NEW_GID}"

    # Get the LDAP Admin Password if we don't already have it.
    getLDAPPassword LDAP_PASSWORD

    # Create the path to the new group's .ldif file:
    GROUP_LDIF=$(realpath "${GROUP_LDIF_PATH}/${GROUPNAME}.ldif")


    # Exporting variables is necessary for the envsubst command to work
    export BASE_DN GROUPNAME NEW_GID
    TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/Group.txt")
    envsubst < "${TEMPLATE_FILE}" > "${GROUP_LDIF}"

    # Import the new user group into LDAP
    resultlt=$(ldapAdd "$GROUP_LDIF" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Failed to create group ${GROUPNAME}"
        echo "$result"
        exit 1
    fi
    echo "  Created group ${GROUPNAME}"
    
else
    echo "Group ${GROUPNAME} exists"

    # The user's group exists..  we need to make sure that
    # it has a GID that matches that of the user.
    result=$(ldapGetGroupID "$GROUPNAME" "$BASE_DN" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to get group ID for ${GROUPNAME}"
        echo "$result"
        exit 1
    fi

    # If the user specified a GID, make sure that the group ID matches it.
    if ! [ -z "$NEW_GID" ]; then
        if [ "$result" != "$NEW_GID" ]; then
            echo "ERROR: Group ID mismatch for ${GROUPNAME}"
            echo "  Expected: ${NEW_GID}"
            echo "  Found:    ${result}"
            exit 1
        fi
    fi

    echo "  GID: ${result}"
fi

