#!/bin/bash

source ./config.sh
source ./ldaplib.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Prompt for the OU Name
read -p "Enter the OU Name: " OU_NAME

# Validate that an OU name was provided
if ! [ -n "$OU_NAME" ]; then
	echo "An OU Name must be provided."
	exit 1
fi

# Check if the OU already exists
if [ "$(ldapOUExists "$OU_NAME" "$BASE_DN")" == "true" ]; then
	echo "An OU with that name already exists."
	exit 1
fi


# Create a temporary file with a unique name
temp_file=$(mktemp)

# Export all of the variables we've collected and use them for templating
export BASE_DN OU_NAME
TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/OrganizationalUnit.txt")
envsubst < "${TEMPLATE_FILE}" > "${temp_file}"

# Import the new user into LDAP
ldapAdd "$temp_file" "$BASE_DN"
