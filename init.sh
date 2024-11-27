#! /bin/bash

source ./config.sh
source ./ldaplib.sh

ou_list=("groups" "users" "services")
group_list=()
service_list=()


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


