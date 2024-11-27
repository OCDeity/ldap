#!/bin/bash

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



read -p "New Group Name: " GROUPNAME

GROUP_LDIF=$(realpath "${GROUP_LDIF_PATH}/${GROUPNAME}.ldif")

# If an .ldif file with that name already exists, ask the user what to do:
if [ -e "${GROUP_LDIF}" ]; then
    read -p "The file ${GROUP_LDIF} exists.  Continue and Overwrite? (y/N)" response
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    if ! [[ "$response" =~ ^(yes|y)$ ]]; then
        echo "Aborting."
        exit 0
    fi
fi



# Check to see if the group name already exists:
result=$(ldapGroupExists "$GROUPNAME" "$BASE_DN")
if [ "$result" == "true" ]; then
    echo "The group ${GROUPNAME} was found: \"${GROUP_EXISTS}\""
    exit 0
fi


# Default first user ID is 10000.  We'll take it or the greatest we found in ldap+1
NEW_GID=$(ldapGetNextGID "$BASE_DN")

# Export all of the variables we've collected and use them for templating
export BASE_DN GROUPNAME NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/GroupTemplate.txt")
envsubst < "${TEMPLATE_FILE}" > "${GROUP_LDIF}"

# Import the new group into LDAP
ldapAdd "$GROUP_LDIF" "$BASE_DN"
