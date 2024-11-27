#!/bin/bash

# Source the LDAP library
source ./ldaplib.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Get the OUs
ldapGetOUs "$BASE_DN"


