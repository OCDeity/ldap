#! /bin/bash

REQUIRED_PARAMS=("GROUPNAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "NEW_GID" "MAPPED_NAME" "TEMPLATE_PATH" "GROUP_LDIF_PATH")

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


echo "Mapping LXC Group"

# Ask for the group name if it's not already set:
if [ -z "$GROUPNAME" ]; then
    read -p "  Group Name: " GROUPNAME
else
    echo "  Group Name: $GROUPNAME"
fi

# We only need to verify the group exists if we don't have  
# a mapped name, a GID.
if [ -z "$MAPPED_NAME" ] || [ -z "$NEW_GID" ]; then

    # check to see if the group exists:
    result=$(ldapGroupExists "$GROUPNAME" "$BASE_DN")
    verifyResult "$?" "$result"
    if [ "$result" == "false" ]; then
        echo "  Group $GROUPNAME not found!"
        exit 1
    fi
fi


# Unless MAPPED_NAME is set, we'll use the default of lxc-<groupname>
if [ -z "$MAPPED_NAME" ]; then
    MAPPED_NAME="lxc-$GROUPNAME"
fi
echo "  Mapped Name: $MAPPED_NAME"

# Check to see if the MAPPED_NAME already exists:
result=$(ldapGroupExists "$MAPPED_NAME" "$BASE_DN")
verifyResult "$?" "$result"
if [ "$result" == "true" ]; then
    echo "  Mapped name $MAPPED_NAME exists!"
    exit 1
fi

# Typically we are not passed a GID.  In this case, we'll
# read the group's GID from LDAP and add our offset to it.
if [ -z "$NEW_GID" ]; then

    # Get GROUPNAME's GID from LDAP:
    result=$(ldapGetGroupID "$GROUPNAME" "$BASE_DN")
    verifyResult "$?" "$result"
    if [ -z "$result" ]; then
        echo "  Unable to get GID for $GROUPNAME"
        exit 1
    fi

    NEW_GID=$(($result + $LXC_OFFSET))
fi
echo "  New GID: $NEW_GID"


# Work out the path to the group .ldif
MAPPED_GROUP_LDIF=$(realpath "${GROUP_LDIF_PATH}/${MAPPED_NAME}.ldif")

# Exporting variables is necessary for the envsubst command to work
export BASE_DN GROUPNAME MAPPED_NAME NEW_GID
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/MapLxcGroup.txt")
envsubst < "${TEMPLATE_FILE}" > "${MAPPED_GROUP_LDIF}"

echo "  Mapped Group LDIF: ${MAPPED_GROUP_LDIF}"

# Get the LDAP Admin Password if we don't already have it.
getLDAPPassword LDAP_PASSWORD

echo -n "  Creating Mapped Group ${MAPPED_NAME}.. "
# Import the new user into LDAP
result=$(ldapAdd "$MAPPED_GROUP_LDIF" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
verifyResult "$?" "$result"

echo "Created."
