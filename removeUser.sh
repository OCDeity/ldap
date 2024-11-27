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


# Ask for the username
if [ -z "$USERNAME" ]; then
    read -p "User to DELETE: " USERNAME
fi

# Check if user exists
user_dn=$(ldapGetUserDN "$USERNAME" "$BASE_DN")
if ! [ -n "$user_dn" ]; then
	echo "User \"$USERNAME\" was not found in \"$BASE_DN\"."
	exit 1
fi


# Get the user's groups
readarray -t user_groups < <(ldapGetUserGroups "$USERNAME" "$BASE_DN")
if [ ${#user_groups[@]} -gt 0 ]; then
	echo "User $USERNAME will be removed from the following groups:"
	printf '%s\n' "${user_groups[@]}"
fi



# Remove the user from each group
for group in "${user_groups[@]}"; do

    # Get the group's DN
    GROUP_DN=$(ldapGetGroupDN "$group" "$BASE_DN")  

    # If we don't yet have the admin password, we'll ask for it.    
    if [ -z "$LDAP_PASSWORD" ]; then
        read -s -p "LDAP Admin Password: " LDAP_PASSWORD
        echo ""
    fi

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

    # If we don't yet have the admin password, we'll ask for it.    
    if [ -z "$LDAP_PASSWORD" ]; then
        read -s -p "LDAP Admin Password: " LDAP_PASSWORD
        echo ""
    fi
        

    ldapdelete -x -D "cn=admin,$BASE_DN" -w "$LDAP_PASSWORD" "$user_group_dn"
fi


# Delete the user
echo "Deleting user $USERNAME..."

# If we don't yet have the admin password, we'll ask for it.    
if [ -z "$LDAP_PASSWORD" ]; then
    read -s -p "LDAP Admin Password: " LDAP_PASSWORD
    echo ""
fi

ldapdelete -x -D "cn=admin,$BASE_DN" -w "$LDAP_PASSWORD" "$user_dn"


# Check if an LXC service mapping exists
LXC_SERVICE_NAME="lxc-$USERNAME"
result=$(ldapUserExists "$LXC_SERVICE_NAME" "$BASE_DN")
if [ "$result" == "true" ] && [ -z "$LXC_SERVICE" ]; then
    echo "The service \"$LXC_SERVICE_NAME\" was found under \"${BASE_DN}\"."
    read -p "Remove \"$LXC_SERVICE_NAME\" and its group? (y/N)" response
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    if [[ "$response" =~ ^(yes|y)$ ]]; then
        LXC_SERVICE="true"
    fi
fi


# Check if the LXC service mapping exist
user_dn=$(ldapGetUserDN "$LXC_SERVICE_NAME" "$BASE_DN")
if [ -n "$user_dn" ]; then

    if [ -z "$LXC_SERVICE" ]; then
        read -p "Delete the LXC mapping \"$LXC_SERVICE_NAME\"? (y/N)" response
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
        if [[ "$response" =~ ^(yes|y)$ ]]; then
            LXC_SERVICE="true"
        fi
    fi

    if [ "$LXC_SERVICE" == "true" ]; then

        # Get the user's groups
        readarray -t user_groups < <(ldapGetUserGroups "$LXC_SERVICE_NAME" "$BASE_DN")
        # Remove the user from each group
        for group in "${user_groups[@]}"; do

            # Get the group's DN
            GROUP_DN=$(ldapGetGroupDN "$group" "$BASE_DN")  

            # If we don't yet have the admin password, we'll ask for it.    
            if [ -z "$LDAP_PASSWORD" ]; then
                read -s -p "LDAP Admin Password: " LDAP_PASSWORD
                echo ""
            fi

            # Create a temporary file with a unique name
            temp_file=$(mktemp)
            
            # For the teplate.. for now...
            USERNAME=$LXC_SERVICE_NAME

            # Export all of the variables we've collected and use them for templating
            export BASE_DN USERNAME GROUP_DN
            TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/RemoveUserFromGroup.txt")
            envsubst < "$TEMPLATE_FILE" > "$temp_file"

            # Attempt to execute the modification in the .ldiff file we just constructed:
            ldapModify "$temp_file" "$BASE_DN" "$LDAP_PASSWORD"
        done

        

        user_group_dn=$(ldapsearch -x -LLL -b "$BASE_DN" "(&(objectClass=posixGroup)(cn=$LXC_SERVICE_NAME))" 2>/dev/null  | grep -E "^dn:" | head -1 | sed 's/dn: //')
        if [ -n "$user_group_dn" ]; then
            echo "Deleting group $LXC_SERVICE_NAME..."

            # If we don't yet have the admin password, we'll ask for it.    
            if [ -z "$LDAP_PASSWORD" ]; then
                read -s -p "LDAP Admin Password: " LDAP_PASSWORD
                echo ""
            fi
            
            ldapdelete -x -D "cn=admin,$BASE_DN" -w "$LDAP_PASSWORD" "$user_group_dn"
        fi


        # Delete the user
        echo "Deleting user $LXC_SERVICE_NAME..."

        # If we don't yet have the admin password, we'll ask for it.    
        if [ -z "$LDAP_PASSWORD" ]; then
            read -s -p "LDAP Admin Password: " LDAP_PASSWORD
            echo ""
        fi

        ldapdelete -x -D "cn=admin,$BASE_DN" -w "$LDAP_PASSWORD" "$user_dn"

    fi
fi


