#! /bin/bash

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

# Prompt for service name
read -p "Enter service name: " SERVICE_NAME

# Check if service already exists
result=$(ldapUserExists "$SERVICE_NAME" "$BASE_DN")
if [ "$result" == "true" ]; then
    echo "The service ${SERVICE_NAME} already exists under '${BASE_DN}'."
    echo "Either remove the service ${SERVICE_NAME} first or modify it instead."
    exit 0
fi

# Work out the path to the service .ldif
SERVICE_LDIF=$(realpath "${SERVICE_LDIF_PATH}/${SERVICE_NAME}.ldif")

# If an .ldif file with that name already exists, ask the user what to do:
if [ -e "${SERVICE_LDIF}" ]; then
    read -p "The file ${SERVICE_LDIF} exists.  Continue and Overwrite? (y/N)" response
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    if ! [[ "$response" =~ ^(yes|y)$ ]]; then
        echo "Aborting."
        exit 0
    fi
fi

# Get the next available UID.  We will use the same ID for the group.
NEW_UID=$(ldapGetNextServiceUID "$BASE_DN")
NEW_GID="$NEW_UID"

# Check if service password hash exists, if not prompt for password
if [ -z "$SERVICE_PW_HASH" ]; then
    read -s -p "Service Password: " SERVICE_PASSWORD
    echo ""
    SERVICE_PW_HASH=$(slappasswd -s "$SERVICE_PASSWORD") 
fi

# Export all of the variables we've collected and use them for templating
export BASE_DN SERVICE_NAME SERVICE_PW_HASH NEW_UID NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/ServiceTemplate.txt")
envsubst < "${TEMPLATE_FILE}" > "${SERVICE_LDIF}"

# Import the new user into LDAP
ldapAdd "$SERVICE_LDIF" "$BASE_DN"

