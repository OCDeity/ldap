#!/bin/bash

REQUIRED_PARAMS=("OU_NAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "TEMPLATE_PATH")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Prompt for the OU Name if it's not already set:	
if [ -z "$OU_NAME" ]; then
    read -p "Create OU: " OU_NAME
else
	echo "Creating OU ${OU_NAME}"
fi

result=$(ldapOUExists "$OU_NAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

# Check if the OU already exists
if [ "$result" == "true" ]; then
	echo "  OU ${OU_NAME} exists"
	exit 0
fi


# Create a temporary file with a unique name
temp_file=$(mktemp)

# Export all of the variables we've collected and use them for templating
export BASE_DN OU_NAME
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/OrganizationalUnit.txt")
envsubst < "${TEMPLATE_FILE}" > "${temp_file}"

echo "  OU_LDIF: ${temp_file}"

# Get the LDAP Admin Password if we don't already have it.
getLDAPPassword LDAP_PASSWORD

# Import the new user into LDAP
result=$(ldapAdd "$temp_file" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
verifyResult "$?" "$result"

echo "  Created OU ${OU_NAME}"
