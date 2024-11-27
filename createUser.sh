#!/bin/bash

REQUIRED_PARAMS=("USERNAME" "SURNAME" "GIVEN" "PW_HASH" "LDAP_PASSWORD")
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


# Get the next available UID if it's not already set:   
if [ -z "$NEW_UID" ]; then
    NEW_UID=$(ldapGetNextUID "$BASE_DN")
fi
if [ -z "$NEW_GID" ]; then
    NEW_GID="$NEW_UID"
fi



# Read in the new username if it's not already set:
if [ -z "$USERNAME" ]; then
    read -p "Username:   " USERNAME
fi

# Work out the path to the user .ldif
USER_LDIF=$(realpath "${USER_LDIF_PATH}/${USERNAME}.ldif")


result=$(ldapUserExists "$USERNAME" "$BASE_DN")
if [ "${result}" == "true" ]; then
    echo "The user ${USERNAME} already exists under '${BASE_DN}'."
    echo "Either remove the user ${USERNAME} first or modify it instead."
    exit 0
fi

if [ -z "$SURNAME" ]; then
    read -p "Surname:    " SURNAME
fi
if [ -z "$GIVEN" ]; then
    read -p "Given Name: " GIVEN
fi
if [ -z "$PWHASH" ]; then
    if [ -z "$PASSWORD" ]; then
        read -s -p "Passowrd:    " PASSWORD
        echo ""
    fi
    PW_HASH=$(slappasswd -s "$PASSWORD")
fi


# Export all of the variables we've collected and use them for templating
export BASE_DN USERNAME SURNAME GIVEN PW_HASH NEW_UID NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/UserTemplate.txt")
envsubst < "${TEMPLATE_FILE}" > "${USER_LDIF}"

# Import the new user into LDAP
ldapAdd "$USER_LDIF" "$BASE_DN"
