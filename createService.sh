#! /bin/bash

REQUIRED_PARAMS=("SERVICENAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "NEW_UID" "NEW_GID" "SERVICE_PW_HASH" "TEMPLATE_PATH" "SERVICE_LDIF_PATH")

source ./ldaplib.sh
source ./config.sh





# Make sure that the output path exists..
if [ ! -d "${SERVICE_LDIF_PATH}" ]; then
    echo "Creating ${SERVICE_LDIF_PATH}"
    mkdir -p "${SERVICE_LDIF_PATH}"
fi

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Prompt for service name if it's not already set:  
if [ -z "$SERVICENAME" ]; then
    read -p "Enter service name: " SERVICENAME
fi


result=$(ldapUserExists "$SERVICENAME" "$BASE_DN")
if [ "$result" != "true" ]; then
    echo "Creating service ${SERVICENAME}"

    # Get the next available UID if it's not already set:   
    if [ -z "$NEW_UID" ]; then
        NEW_UID=$(ldapGetNextServiceUID "$BASE_DN")
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
    # that the service name and that group name match.
    result=$(ldapGroupIdExists "$NEW_GID" "$BASE_DN")
    if [ "$result" == "true" ]; then

        result=$(ldapGetGroupName "$NEW_GID" "$BASE_DN" 2>/dev/null)
        verifyResult "$?" "$result"

        if [ "$result" != "$SERVICENAME" ]; then
            echo "ERROR: Group ID ${NEW_GID} already exists"
            echo "  Expected: ${SERVICENAME}"
            echo "  Found:    ${result}"
            exit 1
        fi
    fi


    # We should be all good on UID & GID.  Report them:
    echo "  UID: ${NEW_UID}"
    echo "  GID: ${NEW_GID}"


    # If we were given a password hash, we will use it.
    # Otherwise, we'll generate a random password and hash it.
    # The idea is that a service doesn't need a password, but
    # the posixAccount object requires one.
    if [ -z "$SERVICE_PW_HASH" ]; then
        random_password=$(openssl rand -base64 16)
        SERVICE_PW_HASH=$(slappasswd -s "$random_password")
    fi
    echo "  PW_HASH: ${SERVICE_PW_HASH}"


    # Get the LDAP Admin Password if we don't already have it.
    getLDAPPassword LDAP_PASSWORD

    # Work out the path to the user .ldif
    SERVICE_LDIF=$(realpath "${SERVICE_LDIF_PATH}/${SERVICENAME}.ldif")
    echo "  SERVICE_LDIF: ${SERVICE_LDIF}"

    # Exporting variables is necessary for the envsubst command to work
    export BASE_DN SERVICENAME SERVICE_PW_HASH NEW_UID NEW_GID
    TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/ServiceTemplate.txt")
    envsubst < "${TEMPLATE_FILE}" > "${SERVICE_LDIF}"

    # Import the new user into LDAP
    result=$(ldapAdd "$SERVICE_LDIF" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
    verifyResult "$?" "$result"

    echo "  Created user ${SERVICENAME}"
else
    echo "Service ${SERVICENAME} exists"
    result=$(ldapGetUserID "$SERVICENAME" "$BASE_DN" 2>/dev/null)
    verifyResult "$?" "$result"

    # If the caller set a new UID, make sure it matches
    # what we read from LDAP.
    if ! [ -z "$NEW_UID" ]; then
        if [ "$result" != "$NEW_UID" ]; then
            echo "ERROR: User ID mismatch for ${SERVICENAME}"
            echo "  Expected: ${NEW_UID}"
            echo "  Read:     ${result}"
            exit 1
        fi
    fi
    NEW_UID="$result"
    echo "  UID: ${NEW_UID}"

    
    # Now for the group ID.  See what is set on the LDAP user.
    result=$(ldapGetUserGroupID "$SERVICENAME" "$BASE_DN" 2>/dev/null)
    verifyResult "$?" "$result"

    # If the caller set a new GID, make sure it matches
    # what we read from LDAP.
    if ! [ -z "$NEW_GID" ]; then
        if [ "$result" != "$NEW_GID" ]; then
            echo "ERROR: Group ID mismatch for ${SERVICENAME}"
            echo "  Expected: ${NEW_GID}"
            echo "  Found:    ${result}"
            exit 1
        fi
    fi
    NEW_GID="$result"
    echo "  GID: ${NEW_GID}"

    if ! [ -z "$SERVICE_PW_HASH" ]; then
        # Note that we could veify that the existing hash 
        # is what the caller provided.  That requires extra
        # permissions.  We'll skip it, at least for now.
        # It may be wise to skip it forever.
        echo "  PW_HASH: (not verified)"
    fi
fi




# Check to see if the user group exists.
result=$(ldapGroupExists "$SERVICENAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

if [ "$result" != "true" ]; then
    echo "Creating service group ${SERVICENAME}"

    # The group name is the same as the service name:
    GROUPNAME="$SERVICENAME"

    echo "  GID: ${NEW_GID}"

    # Get the LDAP Admin Password if we don't already have it.
    getLDAPPassword LDAP_PASSWORD

    # Get the path to the user group .ldif
    SERVICE_GROUP_LDIF=$(realpath "${SERVICE_LDIF_PATH}/${SERVICENAME}-group.ldif")


    # Exporting variables is necessary for the envsubst command to work
    export BASE_DN GROUPNAME NEW_GID
    TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/GroupTemplate.txt")
    envsubst < "${TEMPLATE_FILE}" > "${SERVICE_GROUP_LDIF}"

    # Import the new user group into LDAP
    result=$(ldapAdd "$SERVICE_GROUP_LDIF" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
    verifyResult "$?" "$result"

    echo "  Created group ${SERVICENAME}"
    
else
    echo "Group ${SERVICENAME} exists"

    # The user's group exists..  we need to make sure that
    # it has a GID that matches that of the user.
    result=$(ldapGetGroupID "$SERVICENAME" "$BASE_DN" 2>/dev/null)
    verifyResult "$?" "$result"

    # Make sure that the group ID matches our user's GID.
    if [ "$result" != "$NEW_GID" ]; then
        echo "ERROR: Group ID mismatch for ${SERVICENAME}"
        echo "  Expected: ${NEW_GID}"
        echo "  Found:    ${result}"
        exit 1
    fi

    echo "  GID: ${NEW_GID}"
fi

