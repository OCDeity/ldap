#!/bin/bash

REQUIRED_PARAMS=("USERNAME" "PW_HASH" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN"  "NEW_UID" "NEW_GID" "PASSWORD" "TEMPLATE_PATH" "USER_LDIF_PATH")

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

# Work out the path to the user .ldif
USER_LDIF=$(realpath "${USER_LDIF_PATH}/${USERNAME}.ldif")
USER_GROUP_LDIF=$(realpath "${USER_LDIF_PATH}/${USERNAME}-group.ldif")

result=$(ldapUserExists "$USERNAME" "$BASE_DN")
if [ "$result" != "true" ]; then
    echo "Creating user ${USERNAME}"

    # Get the next available UID if it's not already set:   
    if [ -z "$NEW_UID" ]; then
        NEW_UID=$(ldapGetNextUID "$BASE_DN")
    fi
    result=$(ldapUserIdExists "$NEW_UID" "$BASE_DN")
    if [ "$result" == "true" ]; then
        echo "ERROR: User ID ${NEW_UID} already exists"
        exit 1
    fi

    if [ -z "$NEW_GID" ]; then
        NEW_GID="$NEW_UID"
    fi
    result=$(ldapGroupIdExists "$NEW_GID" "$BASE_DN")
    if [ "$result" == "true" ]; then
        echo "ERROR: Group ID ${NEW_GID} already exists"
        exit 1
    fi

    echo "  UID: ${NEW_UID}"
    echo "  GID: ${NEW_GID}"

    # If no Password has was given, we'll:
    #   - Prompt for one if not given
    #   - Generate a hash for the password
    if [ -z "$PWHASH" ]; then
        if [ -z "$PASSWORD" ]; then
            read -s -p "  Passowrd: " PASSWORD

            # Clear the line.  Note we don't really care if the 
            # username was too long for this to erase it all.
            echo -ne "\r                                   \r"
        fi

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
    READ_UID=$(ldapGetUserID "$USERNAME" "$BASE_DN")
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to get user ID for ${USERNAME}"
        exit 1
    fi
    if [ -z "$NEW_UID" ]; then
        NEW_UID="$READ_UID"
    else
        if [ "$READ_UID" != "$NEW_UID" ]; then
            echo "ERROR: User ID mismatch for ${USERNAME}"
            echo "  Expected: ${NEW_UID}"
            echo "  Read:     ${READ_UID}"
            exit 1
        fi
    fi
    echo "  UID: ${NEW_UID}"

    READ_GID=$(ldapGetUserGroupID "$USERNAME" "$BASE_DN")
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to get group ID for ${USERNAME}"
        exit 1
    fi
    if [ -z "$NEW_GID" ]; then
        NEW_GID="$READ_GID"
    else
        if [ "$READ_GID" != "$NEW_GID" ]; then
            echo "ERROR: Group ID mismatch for ${USERNAME}"
            echo "  Expected: ${NEW_GID}"
            echo "  Read:     ${READ_GID}"
            exit 1
        fi
    fi
    echo "  GID: ${NEW_GID}"
fi

exit 0


# ===============================================
#
#   TODO: Make sure comments are good ^^
#   TODO: Handle Group!
#
# ===============================================



# In this particular case, the group name is the same as the username:
GROUPNAME="${USERNAME}"
result=$(ldapGroupExists "$GROUPNAME" "$BASE_DN")
if [ "${result}" == "true" ]; then
    echo "The group ${GROUPNAME} already exists under '${BASE_DN}'."
    echo "Either remove the group ${GROUPNAME} first or modify it instead."
    exit 0
fi






# Create the user's group!

# Exporting variables is necessary for the envsubst command to work
export BASE_DN GROUPNAME NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/GroupTemplate.txt")
envsubst < "${TEMPLATE_FILE}" > "${USER_GROUP_LDIF}"

# Import the new user group into LDAP
ldapAdd "$USER_GROUP_LDIF" "$BASE_DN" "$LDAP_PASSWORD"
