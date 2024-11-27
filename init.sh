#! /bin/bash

REQUIRED_PARAMS=("LDAP_PASSWORD")
OPTIONAL_PARAMS=("BASE_DN" "USER_LDIF_PATH" "GROUP_LDIF_PATH" "SERVICE_LDIF_PATH" "TEMPLATE_PATH")

source ./config.sh
source ./ldaplib.sh

ou_list=("groups" "users" "services")
group_list=()
service_list=()
lxc_root_mapping="true"


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi

# It is expected that the search domain will match the base DN.  
# If not, we'll prompt the user before we continue.
SEARCH_DOMAIN=$(getBaseDNfromSearchDomain)
if [ "$SEARCH_DOMAIN" != "$BASE_DN" ]; then
    read -p "WARNING:  Search domain ($SEARCH_DOMAIN) does not match base DN ($BASE_DN).  Continue? (y/n): " response
    if [ "$response" != "y" ]; then
        echo "Exiting..."
        exit 1
    fi  
fi

echo "Base DN: $BASE_DN"

echo "Verifying Paths"
# Create the directories if they don't exist
path_list=("$TEMPLATE_PATH" "$USER_LDIF_PATH" "$GROUP_LDIF_PATH" "$SERVICE_LDIF_PATH")
for current_path in "${path_list[@]}"; do
    if [ ! -d "$current_path" ]; then

        # Create the directory
        mkdir -p "$current_path"
        if [ $? -ne 0 ]; then
            echo " x FAILED:  $current_path"
        else
            echo " + Created: $current_path"
        fi
    else
        echo " - Exists:  $current_path"
    fi
done

echo "Creating Organizational Units"

# Create the OU's if they don't exist
for OU_NAME in "${ou_list[@]}"; do

    result=$(ldapOUExists "$OU_NAME" "$BASE_DN")
    if [ "$result" != "true" ]; then

        # Create a temporary file with a unique name
        temp_file=$(mktemp)

        # Export all of the variables we've collected and use them for templating
        export BASE_DN OU_NAME
        TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/OrganizationalUnit.txt")
        envsubst < "${TEMPLATE_FILE}" > "${temp_file}"

        # Only prompt for admin password if not already set
        if [ -z "$LDAP_PASSWORD" ]; then
            read -s -p "OpenLDAP Admin Password: " LDAP_PASSWORD
            echo ""
        fi

        # Import the new user into LDAP
        ldapAdd "$temp_file" "$BASE_DN" "$LDAP_PASSWORD"


        if [ $? -ne 0 ]; then
            echo " x FAILED:  $OU_NAME"
            echo "   RESULT:  $result"
        else 
            echo " + Created: $OU_NAME"
        fi
    else
        echo " - Exists:  $OU_NAME"
    fi
done

echo "Creating Groups"

# Create the groups in group_list
for GROUPNAME in "${group_list[@]}"; do

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
        if [ -z "$LDAP_PASSWORD" ]; then
            read -s -p "OpenLDAP Admin Password: " LDAP_PASSWORD
            echo ""
        fi

        # Import the new group into LDAP
        result=$(ldapAdd "$GROUP_LDIF" "$BASE_DN" "$LDAP_PASSWORD")

        # Check the result of the group addition
        if [ $? -ne 0 ]; then
            echo " x FAILED:  $GROUPNAME"
            echo "   RESULT: $result"
        else 
            echo " + Created: $GROUPNAME"
        fi
    else
        echo " - Exists:  $GROUPNAME"
    fi
done


echo "Creating Services"

# Create the services in service_list
for SERVICE_NAME in "${service_list[@]}"; do

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
        if [ -z "$LDAP_PASSWORD" ]; then
            read -s -p "OpenLDAP Admin Password: " LDAP_PASSWORD
            echo ""
        fi

        # Import the new user into LDAP
        result=$(ldapAdd "$SERVICE_LDIF" "$BASE_DN" "$LDAP_PASSWORD")

        # Check the result of the service addition
        if [ $? -ne 0 ]; then
            echo " x FAILED:  $SERVICE_NAME"
            echo "   RESULT:  $result"
        else 
            echo " + Created: $SERVICE_NAME"
        fi
    else
        echo " - Exists:  $SERVICE_NAME"
    fi
done



if [ "$lxc_root_mapping" == "true" ]; then

    echo "Creating LXC Root Mapping"

    SERVICE_NAME="root"
    LXC_SERVICE_NAME="lxc-root"
    SERVICE_PW_HASH="{SSHA}JRmjUSmev0sqdnRJpVd64gtfu6Rkyc7x"
    LXC_UID="100000"
    LXC_GID="100000"

    result=$(ldapUserExists "$LXC_SERVICE_NAME" "$BASE_DN")
    if [ "$result" != "true" ]; then

        # Work out the path to the service .ldif
        SERVICE_LDIF=$(realpath "${SERVICE_LDIF_PATH}/${LXC_SERVICE_NAME}.ldif")

        # Export all of the variables we've collected and use them for templating
        export BASE_DN LXC_SERVICE_NAME SERVICE_NAME SERVICE_PW_HASH LXC_UID LXC_GID
        TEMPLATE_FILE=$(realpath "${TEMPLATE_PATH}/LxcServiceTemplate.txt")
        envsubst < "${TEMPLATE_FILE}" > "${SERVICE_LDIF}"

        # Only prompt for admin password if not already set
        if [ -z "$LDAP_PASSWORD" ]; then
            read -s -p "OpenLDAP Admin Password: " LDAP_PASSWORD
            echo ""
        fi

        # Import the new user into LDAP
        result=$(ldapAdd "$SERVICE_LDIF" "$BASE_DN" "$LDAP_PASSWORD")
        
        # Check the result of the service addition
        if [ $? -ne 0 ]; then
            echo " x FAILED:  $LXC_SERVICE_NAME"
            echo "   RESULT:  $result"
        else 
            echo " + Created: $LXC_SERVICE_NAME"
        fi
    else
        echo " - Exists:  $LXC_SERVICE_NAME"
    fi
fi
