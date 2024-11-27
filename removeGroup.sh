#! /bin/bash

source ./config.sh
source ./ldaplib.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


read -p "Group to DELETE: " GROUPNAME

GROUP_DN=$(ldapGetGroupDN "$GROUPNAME" "$BASE_DN")

read -s -p "LDAP Admin Password: " LDAP_PASSWORD
echo ""

ldapdelete -x -D "cn=admin,$BASE_DN" -w "$LDAP_PASSWORD" "$GROUP_DN"
