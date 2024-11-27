#! /bin/bash

REQUIRED_PARAMS=()
OPTIONAL_PARAMS=("BASE_DN")

# Load configuration and LDAP library
source ./config.sh
source ./ldaplib.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Get the groups
readarray -t groups < <(ldapGetGroups "$BASE_DN")

# Display the groups
echo "Groups in $BASE_DN:"  
for group in "${groups[@]}"; do
	echo "$group"
done
