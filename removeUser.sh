#!/bin/bash

# Include the ldaplib.sh library
source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


# Ask for the username
read -p "User to DELETE: " USERNAME

# Check if user exists
user_dn=$(ldapGetUserDN "$USERNAME" "$BASE_DN")
if ! [ -n "$user_dn" ]; then
	echo "User $USERNAME was not found."
	exit 1
fi


# Get the user's groups
readarray -t user_groups < <(ldapGetUserGroups "$USERNAME" "$BASE_DN")
if [ ${#user_groups[@]} -gt 0 ]; then
	echo "User $USERNAME will be removed from the following groups:"
	printf '%s\n' "${user_groups[@]}"
fi

read -s -p "LDAP Admin Password: " LDAP_PASSWORD

# Remove the user from each group
for group in "${user_groups[@]}"; do

    # Get the group's DN
    GROUP_DN=$(ldapGetGroupDN "$group" "$BASE_DN")  

    # Create a temporary file with a unique name
    temp_file=$(mktemp)

    # Export all of the variables we've collected and use them for templating
    export BASE_DN USERNAME GROUP_DN
    TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/RemoveUserFromGroup.txt")
    envsubst < "$TEMPLATE_FILE" > "$temp_file"

    # Attempt to execute the modification in the .ldiff file we just constructed:
    ldapModify "$temp_file" "$BASE_DN" "$LDAP_PASSWORD"
done


user_group_dn=$(ldapsearch -x -LLL -b "$BASE_DN" "(&(objectClass=posixGroup)(cn=$USERNAME))" 2>/dev/null  | grep -E "^dn:" | head -1 | sed 's/dn: //')
if [ -n "$user_group_dn" ]; then
    echo "Deleting group $USERNAME..."
    ldapdelete -x -D "cn=admin,$BASE_DN" -w "$LDAP_PASSWORD" "$user_group_dn"
fi


# Delete the user
echo "Deleting user $USERNAME..."
ldapdelete -x -D "cn=admin,$BASE_DN" -w "$LDAP_PASSWORD" "$user_dn"

