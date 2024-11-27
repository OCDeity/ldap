#!/bin/bash

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


# Default first user ID is 10000.  We'll take it or the greatest we found in ldap+1
NEW_UID=$(ldapGetNextUID "$BASE_DN")
NEW_GID="$NEW_GID"


# Read in the new username:
read -p "Username:   " USERNAME

# Work out the path to the user .ldif
USER_LDIF=$(realpath "${USER_LDIF_PATH}/${USERNAME}.ldif")

# If an .ldif file with that name already exists, ask the user what to do:
if [ -e "${USER_LDIF}" ]; then
    read -p "The file ${USER_LDIF} exists.  Continue and Overwrite? (y/N)" response
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    if ! [[ "$response" =~ ^(yes|y)$ ]]; then
        echo "Aborting."
        exit 0
    fi
fi

result=$(ldapUserExists "$USERNAME" "$BASE_DN")
if [ "${result}" == "true" ]; then
    echo "The user ${USERNAME} already exists under '${BASE_DN}'."
    echo "Either remove the user ${USERNAME} first or modify it instead."
    exit 0
fi

read -p "Surname:    " SURNAME
read -p "Given Name: " GIVEN
read -s -p "Passowrd:    " NEW_PASSWORD
echo ""

# Convert the password entered to an OpenLDAP compatible hash
PW_HASH=$(slappasswd -s "$NEW_PASSWORD")

# Export all of the variables we've collected and use them for templating
export BASE_DN USERNAME SURNAME GIVEN PW_HASH NEW_UID NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/UserTemplate.txt")
envsubst < "${TEMPLATE_FILE}" > "${USER_LDIF}"

# Import the new user into LDAP
ldapAdd "$USER_LDIF" "$BASE_DN"
