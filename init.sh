#! /bin/bash

source ./config.sh
source ./ldaplib.sh

ou_list=("groups" "users" "services")
group_list=("media")
service_list=("sabnzbd"  "sonarr"  "radarr" "jellyfin" "jellyseerr")
media_members=("sabnzbd"  "sonarr"  "radarr" "jellyfin")


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# Create the directories if they don't exist
path_list=("$TEMPLATE_PATH" "$USER_LDIF_PATH" "$GROUP_LDIF_PATH" "$SERVICE_LDIF_PATH")
for current_path in "${path_list}"; do
    if [ ! -d "$current_path" ]; then
        echo "Creating directory: $current_path"
        mkdir -p "$current_path"
    fi
done


# Create the OU's if they don't exist
for OU_NAME in "${ou_list}"; do

    result=$(ldapOUExists "$OU_NAME" "$BASE_DN")
    if [ "$result" != "true" ]; then

        # Create a temporary file with a unique name
        temp_file=$(mktemp)

        # Export all of the variables we've collected and use them for templating
        export BASE_DN OU_NAME
        TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/OrganizationalUnit.txt")
        envsubst < "${TEMPLATE_FILE}" > "${temp_file}"

        # Only prompt for admin password if not already set
        if [ -z "$admin_password" ]; then
            read -s -p "OpenLDAP Admin Password: " admin_password
            echo ""
        fi

        # Import the new user into LDAP
        ldapAdd "$temp_file" "$BASE_DN" "$admin_password"
    fi
done


# # Check if the sudoRole objectClass is available.  This will tell us if 
# # we can add the sudoers group. 
# result=$(ldapsearch -x -b "cn=schema,cn=config" -s sub '(cn=sudo)' dn)
# if [ -z "$result" ]; then
#     echo "The sudo schema is not available. Please add it using:"
#     echo "ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/sudo.ldif"
#     exit 1
# fi


# # Check if sudoers group exists before adding
# result=$(ldapGroupExists "sudoers" "$BASE_DN")
# if [ "$result" != "true" ]; then

#     # cp /usr/share/doc/sudo-ldap/schema.OpenLDAP /etc/ldap/schema/sudo.schema

#     schema_numbers=$(ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=schema,cn=config" -Q -s one "objectClass=olcSchemaConfig" dn | grep -oP "cn=\K\{[0-9]+\}" | sed 's/[{} ]//g')
#     # If there are no schemas, start from 0, otherwise find the max number
#     if [ -z "$schema_numbers" ]; then
#         next_number=0
#     else
#         # Sort the numbers and get the last one which will be the highest
#         highest_number=$(echo "$schema_numbers" | sort -n | tail -n 1)
#         next_number=$((highest_number + 1))
#     fi

#     echo "Next available number is: $next_number"
#     exit 0

#     # Only prompt for admin password if not already set
#     if [ -z "$admin_password" ]; then
#         read -s -p "OpenLDAP Admin Password: " admin_password
#         echo ""
#     fi

#     # Add the initial settings, including sudoers group
#     SUDOERS_LDIF=$(realpath "${TEMPLATE_PATH}/Sudoers.txt")
#     result=$(ldapAdd "$SUDOERS_LDIF" "$BASE_DN" "$admin_password")

#     if [ $? -ne 0 ]; then
#         echo "Failed to add sudoers group.  Exiting."
#         echo "Make sure the sudo schema is available and try again."
#         exit 1
#     fi  
# fi


# Create the groups in group_list
for GROUPNAME in "${group_list}"; do

    # Check to see if the group name already exists:
    result=$(ldapGroupExists "$GROUPNAME" "$BASE_DN")
    if [ "$result" != "true" ]; then

        # Default first user ID is 10000.  We'll take it or the greatest we found in ldap+1
        NEW_GID=$(ldapGetNextGID "$BASE_DN")

        # Work out the path to the group .ldif
        GROUP_LDIF=$(realpath "${GROUP_LDIF_PATH}/${GROUPNAME}.ldif")

        # Export all of the variables we've collected and use them for templating
        export BASE_DN GROUPNAME NEW_GID
        TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/GroupTemplate.txt")
        envsubst < "${TEMPLATE_FILE}" > "${GROUP_LDIF}"

        # Only prompt for admin password if not already set
        if [ -z "$admin_password" ]; then
            read -s -p "OpenLDAP Admin Password: " admin_password
            echo ""
        fi

        # Import the new group into LDAP
        ldapAdd "$GROUP_LDIF" "$BASE_DN" "$admin_password"
    fi
done

echo "Creating services..."

# Create the services in service_list
for SERVICE_NAME in "${service_list}"; do

    # Check if the service already exists
    result=$(ldapUserExists "$SERVICE_NAME" "$BASE_DN")
    if [ "$result" != "true" ]; then    

        # Work out the path to the service .ldif
        SERVICE_LDIF=$(realpath "${SERVICE_LDIF_PATH}/${SERVICE_NAME}.ldif")

        # Get the next available UID.  We will use the same ID for the group.
        NEW_UID=$(ldapGetNextServiceUID "$BASE_DN")
        NEW_GID="$NEW_UID"

        # Export all of the variables we've collected and use them for templating
        export BASE_DN SERVICE_NAME SERVICE_PW_HASH NEW_UID NEW_GID
        TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/ServiceTemplate.txt")
        envsubst < "${TEMPLATE_FILE}" > "${SERVICE_LDIF}"

        # Only prompt for admin password if not already set
        if [ -z "$admin_password" ]; then
            read -s -p "OpenLDAP Admin Password: " admin_password
            echo ""
        fi

        # Import the new user into LDAP
        ldapAdd "$SERVICE_LDIF" "$BASE_DN" "$admin_password"
    fi
done

echo "Adding media members to the media group..."



GROUP_DN=$(ldapGetGroupDN "media" "$BASE_DN")
if ! [ -n "$GROUP_DN" ]; then
    echo "The group \"media\" was not found."
    exit 0
fi

# Add the media members to the media group
for USERNAME in "${media_members}"; do
    result=$(ldapIsMember "media" "$USERNAME" "$BASE_DN")
    if [ "$result" != "true" ]; then



        # Create a temporary file with a unique name
        temp_file=$(mktemp)

        # Export all of the variables we've collected and use them for templating
        export BASE_DN USERNAME GROUP_DN
        TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/AddUserToGroup.txt")
        envsubst < "$TEMPLATE_FILE" > "$temp_file"

        # Only prompt for admin password if not already set
        if [ -z "$admin_password" ]; then
            read -s -p "OpenLDAP Admin Password: " admin_password
            echo ""
        fi

        # Attempt to execute the modification in the .ldiff file we just constructed:
        ldapModify "$temp_file" "$BASE_DN" "$admin_password"
    fi
done
