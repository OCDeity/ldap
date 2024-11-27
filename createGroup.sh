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

# Create the path to the new group's .ldif file:
GROUP_LDIF=$(realpath "${GROUP_LDIF_PATH}/${GROUPNAME}.ldif")


# Check to see if the group name already exists:
result=$(ldapGroupExists "$GROUPNAME" "$BASE_DN")
if [ "$result" == "true" ]; then
    echo "The group ${GROUPNAME} already exists."
    exit 0
fi


# Get the next available GID if it's not already set:
if [ -z "$NEW_GID" ]; then
    NEW_GID=$(ldapGetNextGID "$BASE_DN")
fi

# Export all of the variables we've collected and use them for templating
export BASE_DN GROUPNAME NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/GroupTemplate.txt")
envsubst < "${TEMPLATE_FILE}" > "${GROUP_LDIF}"

# Import the new group into LDAP
ldapAdd "$GROUP_LDIF" "$BASE_DN" "$LDAP_PASSWORD"
