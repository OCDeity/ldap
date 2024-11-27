#! /bin/bash

REQUIRED_PARAMS=("GROUPNAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN")

source ./config.sh
source ./ldaplib.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

if [ -z "$GROUPNAME" ]; then
    read -p "Group to DELETE: " GROUPNAME
fi

GROUP_DN=$(ldapGetGroupDN "$GROUPNAME" "$BASE_DN")
if [ -z "$GROUP_DN" ]; then
    echo "The group \"$GROUPNAME\" was not found in \"$BASE_DN\"."
    exit 1
fi

if [ -z "$LDAP_PASSWORD" ]; then
    read -s -p "LDAP Admin Password: " LDAP_PASSWORD
    echo ""
fi

ldapdelete -x -D "cn=admin,$BASE_DN" -w "$LDAP_PASSWORD" "$GROUP_DN"
