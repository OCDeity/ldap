#!/bin/bash

REQUIRED_PARAMS=("SERVICENAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "MAPPED_NAME" "NEW_UID" "NEW_GID" "TEMPLATE_PATH" "SERVICE_LDIF_PATH")

# Include our settings:
source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Make sure that the output path exists..
if [ ! -d "${SERVICE_LDIF_PATH}" ]; then
    echo "Creating ${SERVICE_LDIF_PATH}"
    mkdir -p "${SERVICE_LDIF_PATH}"
fi



echo "Mapping LXC Service"

# Read in the new servicename if it's not already set:
if [ -z "$SERVICENAME" ]; then
    read -p "  Service Name: " SERVICENAME
else
    echo "  Service Name: $SERVICENAME"
fi

# First check to be sure that the service user exists in LDAP:
result=$(ldapUserExists "$SERVICENAME" "$BASE_DN")
verifyResult "$?" "$result"
if [ "$result" == "false" ]; then
    echo "  Service $SERVICENAME not found."
    exit 1
fi


# Unless MAPPED_NAME is set, we'll use the default of lxc-<servicename>
if [ -z "$MAPPED_NAME" ]; then
    MAPPED_NAME="lxc-$SERVICENAME"
fi
echo "  Mapped Name: $MAPPED_NAME"


# Check to see if the MAPPED_NAME already exists:
result=$(ldapUserExists "$MAPPED_NAME" "$BASE_DN")
verifyResult "$?" "$result"
if [ "$result" == "true" ]; then
    echo "  Mapped name $MAPPED_NAME exists!"
    exit 1
fi


# Typically we are not passed a UID.  In this case, we'll
# read the user's UID from LDAP and add our offset to it.
if [ -z "$NEW_UID" ]; then
    # Get the user's UID:
    result=$(ldapGetUserID "$SERVICENAME" "$BASE_DN")
    verifyResult "$?" "$result"

    # If we were unable to read the UID, we cannot continue.
    if [ -z "$result" ]; then
        echo "  Unable to get UID for $SERVICENAME"
        exit 1
    fi

    NEW_UID=$(($result + $LXC_OFFSET))
fi

# Check to see if the UID already exists:
result=$(ldapUserIdExists "$NEW_UID" "$BASE_DN")
verifyResult "$?" "$result"
if [ "$result" == "true" ]; then
    echo "  UID $NEW_UID exists!"
    exit 1
fi
echo "  UID: $NEW_UID"


# Typically we are not passed a GID.  In this case, we'll
# read the user's GID from LDAP and add our offset to it.
if [ -z "$NEW_GID" ]; then
    # Get the user's GID:
    result=$(ldapGetUserGroupID "$SERVICENAME" "$BASE_DN")
    verifyResult "$?" "$result"

    # If we were unable to read the GID, we cannot continue.
    if [ -z "$result" ]; then
        echo "  Unable to get GID for $SERVICENAME"
        exit 1
    fi

    NEW_GID=$(($result + $LXC_OFFSET))
fi

# Check to see if the GID already exists:
result=$(ldapGroupIdExists "$NEW_GID" "$BASE_DN")
verifyResult "$?" "$result"
if [ "$result" == "true" ]; then
    echo "  GID $NEW_GID already exists!"
    exit 1
fi
echo "  GID: $NEW_GID"


# Generate a random string of 32 characters.  This will be used to generate
# the password hash.  The idea is to generate something nobody has access to.
random_password=$(openssl rand -base64 12 | tr -d '\n' | cut -c1-32)
PW_HASH=$(slappasswd -s "$random_password" -h {SSHA})
echo "  PW_HASH: $PW_HASH (Randomly Generated)"

# Work out the path to the user .ldif
MAPPED_SERVICE_LDIF=$(realpath "${SERVICE_LDIF_PATH}/${MAPPED_NAME}.ldif")

# Exporting variables is necessary for the envsubst command to work
export BASE_DN SERVICENAME MAPPED_NAME PW_HASH NEW_UID NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/MapLxcService.txt")
envsubst < "${TEMPLATE_FILE}" > "${MAPPED_SERVICE_LDIF}"

echo "  Mapped Service LDIF: ${MAPPED_SERVICE_LDIF}"

# Get the LDAP Admin Password if we don't already have it.
getLDAPPassword LDAP_PASSWORD

echo -n "  Creating Mapped Service ${MAPPED_NAME}.. "
# Import the new user into LDAP
result=$(ldapAdd "$MAPPED_SERVICE_LDIF" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
verifyResult "$?" "$result"

echo "Created."
