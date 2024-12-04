#! /bin/bash

REQUIRED_PARAMS=("OU_NAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi



echo "Remove (DELETE) Organizational Unit"

# Ask for the username
if [ -z "$OU_NAME" ]; then
    read -p "  OU Name: " OU_NAME
else 
    echo "  OU Name: $OU_NAME"
fi

# Verify that the OU exists..
result=$(ldapOUExists "$OU_NAME" "$BASE_DN")
verifyResult "$?" "$result"
if [ "$result" = "false" ]; then
    echo "  OU \"$OU_NAME\" not found."
    exit 1
fi


# Check to see if the OU has any subordinates
result=$(ldapGetOUMembers "$OU_NAME" "$BASE_DN" "$LDAP_PASSWORD")
verifyResult "$?" "$result"
if [ -n "$result" ]; then
    echo "  The Organizational Unit has the following subordinates."
    echo "  They must be removed before the OU can be deleted:"

        # look up the UID for each user and add it to GROUP_DATA
    while IFS= read -r ou_subordinate; do
        echo "    - $ou_subordinate"
    done <<< "$result"

    exit 1
fi

# Get the OU's DN.
result=$(ldapGetOUDN "$OU_NAME" "$BASE_DN")
verifyResult "$?" "$result"
OU_DN=$result

# Make sure we have the admin password
getLDAPPassword LDAP_PASSWORD

# Remove the OU
echo -n "  Removing OU \"$OU_DN\".. "
result=$(ldapDelete "$OU_DN" "$BASE_DN" "$LDAP_PASSWORD")
verifyResult "$?" "$result"

echo "  Removed."