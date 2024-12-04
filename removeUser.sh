#!/bin/bash

REQUIRED_PARAMS=("USERNAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "LXC_SERVICE")

# Include the ldaplib.sh library
source ./ldaplib.sh
source ./config.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

echo "Remove (DELETE) User"

# Ask for the username
if [ -z "$USERNAME" ]; then
    read -p "  Username: " USERNAME
else 
    echo "  Username: $USERNAME"
fi

# Check if user exists
user_dn=$(ldapGetUserDN "$USERNAME" "$BASE_DN")
if ! [ -n "$user_dn" ]; then
	echo "  User \"$USERNAME\" found."
	exit 1
fi


# Get the user's groups
readarray -t user_groups < <(ldapGetUserGroups "$USERNAME" "$BASE_DN")
if [ ${#user_groups[@]} -gt 0 ]; then
	echo "  Remove \"$USERNAME\" from groups:"
	printf '    - %s\n' "${user_groups[@]}"

    # Get the LDAP Admin Password if we don't already have it.
    getLDAPPassword LDAP_PASSWORD

    echo "  Executing Remove:"

    # Remove the user from each group
    for group in "${user_groups[@]}"; do

        # Get the group's DN
        GROUP_DN=$(ldapGetGroupDN "$group" "$BASE_DN")
        verifyResult "$?" "$GROUP_DN"

        # Create a temporary file with a unique name
        temp_file=$(mktemp)

        echo -n "    - $GROUP_DN (Temp LDIF: $temp_file).. "

        # Export all of the variables we've collected and use them for templating
        export BASE_DN USERNAME GROUP_DN
        TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/RemoveUserFromGroup.txt")
        envsubst < "$TEMPLATE_FILE" > "$temp_file"

        # Attempt to execute the modification in the .ldiff file we just constructed:
        result=$(ldapModify "$temp_file" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
        verifyResult "$?" "$result"

        echo "  Removed."
    done

fi


# Get the user's group DN
GROUP_DN=$(ldapGetGroupDN "$USERNAME" "$BASE_DN")
verifyResult "$?" "$GROUP_DN"

if [ -n "$GROUP_DN" ]; then
    # Get the LDAP Admin Password if we don't already have it.
    getLDAPPassword LDAP_PASSWORD

    echo -n "  Removing user's group $GROUP_DN.. "

    result=$(ldapDelete "$GROUP_DN" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
    verifyResult "$?" "$result"

    echo "  removed."
fi




# Get the LDAP Admin Password if we don't already have it.
getLDAPPassword LDAP_PASSWORD

# Delete the user
echo -n "  Removing user $user_dn.. "
result=$(ldapDelete "$user_dn" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
verifyResult "$?" "$result"

echo "  removed."
