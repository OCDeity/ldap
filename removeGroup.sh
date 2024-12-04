#! /bin/bash

REQUIRED_PARAMS=("GROUPNAME" "LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi



echo "Remove (DELETE) Group"

# Ask for the username
if [ -z "$GROUPNAME" ]; then
    read -p "  Group Name: " GROUPNAME
else 
    echo "  Group Name: $GROUPNAME"
fi


# Get the group's DN for the delete operation..
result=$(ldapGetGroupDN "$GROUPNAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

if [ -z "$result" ]; then
    echo "  Group \"$GROUPNAME\" not found."
    exit 1
fi

GROUP_DN=$result



# Get the list of users in the group first..
# Display the group members
result=$(ldapGetMembers "$GROUPNAME" "$BASE_DN" 2>/dev/null)
verifyResult "$?" "$result"

# Only if we've got a user list, display it:
if [ ${#result[@]} -gt 0 ]; then

    echo "  Removing members from group \"$GROUP_DN\":"
    getLDAPPassword LDAP_PASSWORD

    # look up the UID for each user and add it to GROUP_DATA
    while IFS= read -r group_user; do

        USERNAME=$group_user

        # Create a temporary file with a unique name
        temp_file=$(mktemp)
        echo -n "    - $USERNAME (Temp LDIF: $temp_file).. "

        # Export all of the variables we've collected and use them for templating
        export BASE_DN USERNAME GROUP_DN
        TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/RemoveUserFromGroup.txt")
        envsubst < "$TEMPLATE_FILE" > "$temp_file"


        # Attempt to execute the modification in the .ldiff file we just constructed:
        result=$(ldapModify "$temp_file" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
        verifyResult "$?" "$result"

        echo "  Removed."
    done <<< "$result"
fi





getLDAPPassword LDAP_PASSWORD

echo -n "  Removing group $GROUP_DN.. "
result=$(ldapDelete "$GROUP_DN" "$BASE_DN" "$LDAP_PASSWORD" 2>/dev/null)
verifyResult "$?" "$result"

echo "  Removed."
