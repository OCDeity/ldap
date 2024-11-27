#! /bin/bash

REQUIRED_PARAMS=("SERVICE_NAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "NEW_UID" "NEW_GID" "SERVICE_PW_HASH" "SERVICE_PASSWORD" "LXC_SERVICE" "TEMPLATE_PATH" "SERVICE_LDIF_PATH")

source ./config.sh
source ./ldaplib.sh

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
if [ -z "$SERVICE_NAME" ]; then
    read -p "Enter service name: " SERVICE_NAME
fi

# Check if service already exists
result=$(ldapUserExists "$SERVICE_NAME" "$BASE_DN")
if [ "$result" == "true" ]; then
    echo "The service ${SERVICE_NAME} already exists under '${BASE_DN}'."
    echo "Either remove the service ${SERVICE_NAME} first or modify it instead."
    exit 0
fi

# Work out the path to the service .ldif
SERVICE_LDIF=$(realpath "${SERVICE_LDIF_PATH}/${SERVICE_NAME}.ldif")


# Get the next available UID.  We will use the same ID for the group.
if [ -z "$NEW_UID" ]; then
    NEW_UID=$(ldapGetNextServiceUID "$BASE_DN")
fi
if [ -z "$NEW_GID" ]; then
    NEW_GID="$NEW_UID"
fi

# Check if service password hash exists, if not prompt for password
if [ -z "$SERVICE_PW_HASH" ]; then
    if [ -z "$SERVICE_PASSWORD" ]; then
        read -s -p "Service Password: " SERVICE_PASSWORD
        echo ""
    fi
    SERVICE_PW_HASH=$(slappasswd -s "$SERVICE_PASSWORD") 
fi

# Export all of the variables we've collected and use them for templating
export BASE_DN SERVICE_NAME SERVICE_PW_HASH NEW_UID NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/ServiceTemplate.txt")
envsubst < "${TEMPLATE_FILE}" > "${SERVICE_LDIF}"

# If we don't yet have the admin password, we'll ask for it.
if [ -z "$LDAP_PASSWORD" ]; then
    read -s -p "LDAP Admin Password: " LDAP_PASSWORD
    echo ""
fi

# Import the new user into LDAP
ldapAdd "$SERVICE_LDIF" "$BASE_DN" "$LDAP_PASSWORD"



LXC_SERVICE_NAME="lxc-$SERVICE_NAME"
result=$(ldapUserExists "$LXC_SERVICE_NAME" "$BASE_DN")
if [ "$result" == "true" ]; then
    echo "The service $LXC_SERVICE_NAME was already found under '${BASE_DN}'."
    exit 0
fi



if [ "$LXC_SERVICE" == "true" ]; then

    # Export all of the variables we've collected and use them for templating
    export BASE_DN LXC_SERVICE_NAME SERVICE_NAME SERVICE_PW_HASH NEW_UID NEW_GID
    TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/LxcServiceTemplate.txt")
    envsubst < "${TEMPLATE_FILE}" > "${SERVICE_LDIF}"

    # Import the new user into LDAP
    ldapAdd "$SERVICE_LDIF" "$BASE_DN" "$LDAP_PASSWORD"
fi
