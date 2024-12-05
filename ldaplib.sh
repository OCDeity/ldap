#!/bin/bash


# ====================================
#  Parameters
# ====================================
#  None
# ====================================
getBaseDNfromSearchDomain() {
    # This should get our search domain from the network settings:
    search_domain=$(grep ^search /etc/resolv.conf | cut -d' ' -f2-)
    if [ -z "$search_domain" ]; then 
        echo "Search domain not found in /etc/resolv.conf"
        exit 1
    fi

    # This will separate $search_domain out by ' ' into a $search_domains array:
    IFS=' ' read -r -a search_domains <<< "$search_domain"

    # Note: There may be multiple domains.  I expect to find one.
    if [ "${#search_domains[@]}" -ne 1 ]; then
        echo "Expected a single search domain in /etc/resolv.conf"
        exit 1
    fi

    # Split the domain into parts
    IFS='.' read -r -a domain_parts <<< "${search_domains[0]}"

    # Build our BaseDN string from the parts of the parsed search domain:
    base_dn="dc=${domain_parts[0]}"
    for item in "${domain_parts[@]:1}"; do
        base_dn="$base_dn,dc=$item"
    done

    echo $base_dn
}

# ====================================
#  Parameters
# ====================================
#  None
# ====================================
getBaseDN() {

	# Get the base DN from OpenLDAP
	ldapsearch -x -s base -LLL -b "" namingContexts 2>/dev/null | grep -E "^namingContexts:" | sed 's/namingContexts: //g'
}


# ====================================
#  Parameters
# ====================================
#  1 - Variable to store the password
#     NOTE: Do not dereference with $
# ====================================
getLDAPPassword() {
	local -n local_password=$1
    if [ -z "$local_password" ]; then
        read -s -p "OpenLDAP Admin Password: " local_password
		
		# Clear the line
        echo -ne "\r                          \r"
    fi
}


# ====================================
#  Parameters
# ====================================
#  1 - Path to LDIF File to be added
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
#  3 - LDAP Admin Password (Optional)
#      If omitted, the user is asked
# ====================================
ldapAdd() {

	local ldif_file=$1
	local base_dn=$2
	local admin_password=$3

    # Make sure that the .ldif file exists
	if ! [ -e "$ldif_file" ]; then 
		echo "The .ldif file does not exist: $ldif_file"
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# If the admin_password was not passed, ask for it:
	if ! [ -n "$admin_password" ]; then
        read -s -p "OpenLDAP Admin Password: " admin_password
		echo ""
    fi

    ldapadd -x -D "cn=admin,${base_dn}" -w "${admin_password}" -f "${ldif_file}"
    if ! [ $? -eq 0 ]; then
        echo "Failed to import LDIF file. Please check your credentials and file path."
        echo "File: $ldif_file"
        echo "BaseDN: $base_dn"
        exit 1
    fi
}


# =====================================
#  1 - Path to LDIF File to be executed
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
#  3 - LDAP Admin Password (Optional)
#      If omitted, the user is asked
# =====================================
ldapModify() {

	local ldif_file=$1
	local base_dn=$2
	local admin_password=$3

    # Make sure that the .ldif file exists
	if ! [ -e "$ldif_file" ]; then 
		echo "The .ldif file does not exist: \"$ldif_file\""
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# If the admin_password was not passed, ask for it:
	if ! [ -n "$admin_password" ]; then
        read -s -p "OpenLDAP Admin Password: " admin_password
		echo ""
    fi

    ldapmodify -x -D "cn=admin,${base_dn}" -w "${admin_password}" -f "${ldif_file}"
    if ! [ $? -eq 0 ]; then
        echo "Failed to execute changes in LDIF file. Please check your credentials and file path."
        echo "File: $ldif_file"
        echo "BaseDN: $base_dn"
        exit 1
    fi
}


# ====================================
#  Parameters
# ====================================
#  1 - DN to remove
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
#  3 - LDAP Admin Password (Optional)
#      If omitted, the user is asked
# ====================================
ldapDelete() {

	local remove_dn=$1
	local base_dn=$2
	local admin_password=$3

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# If the admin_password was not passed, ask for it:
	if ! [ -n "$admin_password" ]; then
        read -s -p "OpenLDAP Admin Password: " admin_password
		echo ""
    fi

	ldapdelete -x -D "cn=admin,$base_dn" -w "$admin_password" "$remove_dn"
}


# ====================================
#  Parameters
# ====================================
#  1 - Username to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapUserExists() {

	local username=$1
	local base_dn=$2

	# Make sure we have a username.
	if ! [ -n "$username" ]; then
		echo "Expected a username as the first parameter."
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Look for a posixAccount entry for the user:
	result=$(ldapsearch -x -LLL -b "${base_dn}" "(&(objectClass=posixAccount)(uid=${username}))" dn 2>/dev/null | grep -E "^dn:" | head -1 | sed 's/dn: //')
	if [ -n "${result}" ]; then
		echo true
	else
		echo false
	fi
}


# ====================================
#  Parameters
# ====================================
#  1 - Username to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetUserID() {
	local username=$1
	local base_dn=$2

	# Make sure we have a username
	if ! [ -n "$username" ]; then
		echo "Expected a username as the first parameter."
		exit 1
	fi

	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount)(uid=$username))" uidNumber 2>/dev/null | grep -E "^uidNumber:" | head -1 | sed 's/uidNumber: //'
}



# ====================================
#  Parameters
# ====================================
#  1 - Username to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetUserGroupID() {
	local username=$1
	local base_dn=$2

	# Make sure we have a username
	if ! [ -n "$username" ]; then
		echo "Expected a username as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount)(uid=$username))" gidNumber 2>/dev/null | grep -E "^gidNumber:" | head -1 | sed 's/gidNumber: //'
}



# ====================================
#  Parameters
# ====================================
#  1 - Group Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetGroupID() {
	local group_name=$1
	local base_dn=$2

	# Make sure we have a group name
	if ! [ -n "$group_name" ]; then
		echo "Expected a group name as the first parameter."
		exit 1
	fi

	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)(cn=$group_name))" gidNumber 2>/dev/null | grep -E "^gidNumber:" | head -1 | sed 's/gidNumber: //'
}	


# ====================================
#  Parameters
# ====================================
#  1 - User ID to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapUserIdExists() {
	local user_id=$1
	local base_dn=$2

	# Make sure we have a user_id
	if ! [ -n "$user_id" ]; then
		echo "Expected a user ID as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	result=$(ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount)(uidNumber=$user_id))" uidNumber 2>/dev/null | grep -E "^uidNumber:" | head -1 | sed 's/uidNumber: //')
	if [ -n "$result" ]; then
		echo true
	else
		echo false
	fi
}



# ====================================
#  Parameters
# ====================================
#  1 - Group ID to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGroupIdExists() {
	local group_id=$1
	local base_dn=$2

	# Make sure we have a group_id
	if ! [ -n "$group_id" ]; then
		echo "Expected a group ID as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	result=$(ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)(gidNumber=$group_id))" gidNumber 2>/dev/null | grep -E "^gidNumber:" | head -1 | sed 's/gidNumber: //')
	if [ -n "$result" ]; then
		echo true
	else
		echo false
	fi
}


# ====================================
#  Parameters
# ====================================
#  1 - Group Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetGroupDN() {
	local group_name=$1
	local base_dn=$2

	# Make sure we have a group name
	if ! [ -n "$group_name" ]; then
		echo "Expected a group name as the first parameter."
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Look for a posixGroup entry for the group:
	ldapsearch -x -LLL -b "${base_dn}" "(&(objectClass=posixGroup)(cn=${group_name}))" dn 2>/dev/null | grep -E "^dn:" | head -1 | sed 's/dn: //'
}


# ====================================
#  Parameters
# ====================================
#  1 - Group Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGroupExists() {

	# Get the parameters
	local group_name=$1
	local base_dn=$2

	# Make sure we have a group name
	if ! [ -n "$group_name" ]; then
		echo "Expected a group name as the first parameter."
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	result=$(ldapGetGroupDN "$group_name" "$base_dn")
	if [ -n "$result" ]; then
		echo true
	else
		echo false
	fi
}


# ====================================
#  Parameters
# ====================================
#  1 - Group Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetGroupDN() {
	local group_name=$1
	local base_dn=$2

	# Make sure we have a group name
	if ! [ -n "$group_name" ]; then
		echo "Expected a group name as the first parameter."
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Look for a posixGroup entry for the group:
	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)(cn=$group_name))" dn 2>/dev/null | grep -E "^dn:" | head -1 | sed 's/dn: //'
}



# ====================================
#  Parameters
# ====================================
#  1 - Username to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetUserDN() {
	local username=$1
	local base_dn=$2

	# Make sure we have a username
	if ! [ -n "$username" ]; then
		echo "Expected a username as the first parameter."
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Look for a posixAccount entry for the user:
	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount)(uid=$username))" dn 2>/dev/null | grep -E "^dn:" | head -1 | sed 's/dn: //'
}



# ====================================
#  Parameters
# ====================================
#  1 - OU Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetOUDN() {
	local ou_name=$1
	local base_dn=$2

	# Make sure we have an ou_name
	if ! [ -n "$ou_name" ]; then
		echo "Expected an OU name as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Search for the OU
	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=organizationalUnit)(ou=$ou_name))" dn 2>/dev/null | grep -E "^dn:" | head -1 | sed 's/dn: //'
}



# ====================================
#  Parameters
# ====================================
#  1 - OU Name to search for members
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
#  3 - Admin Password
# ====================================
ldapGetOUMembers() {
	local ou_name=$1
	local base_dn=$2
	local admin_password=$3

	# Make sure we have an ou_name
	if ! [ -n "$ou_name" ]; then
		echo "Expected an OU name as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Make sure we have an admin_password
	if ! [ -n "$admin_password" ]; then
		read -p "  Admin Password: " admin_password
	fi

	# Search for the OU members
	ldapsearch -x -D "cn=admin,$base_dn" -w "$admin_password" -b "ou=$ou_name,$base_dn" -s sub "(objectClass=*)" uid 2>/dev/null | grep -E "^uid:" | sed 's/uid: //g'
}


# =====================================
#  Parameters
# =====================================
#  1 - Group Name to search for members
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# =====================================
ldapGetMembers() {
	local group_name=$1
	local base_dn=$2

	# Make sure we have a group name
	if ! [ -n "$group_name" ]; then
		echo "Expected a group name as the first parameter."
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)(cn=$group_name))" memberUid 2>/dev/null | grep -E "^memberUid:" | sed 's/memberUid: //g'
}


# ======================================
#  Parameters
# ======================================
#  1 - Group Name to test for membership
#  2 - Username to test for
#  3 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ======================================
ldapIsMember() {
	local group_name=$1
	local username=$2
	local base_dn=$3

	# Make sure we have a group name
	if ! [ -n "$group_name" ]; then
		echo "Expected a group name as the first parameter."
		exit 1
	fi

	# Make sure we have a username
	if ! [ -n "$username" ]; then
		echo "Expected username as the second parameter."
		exit 1
	fi

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	result=$(ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)(cn=$group_name)(memberUid=$username))" memberUid 2>/dev/null)
	if [ -n "$result" ]; then
		echo true
	else
		echo false
	fi
}



# ====================================
#  Parameters
# ====================================
#  1 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetNextUID() {

	local base_dn=$1

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Default first user ID is 2000.  We'll take it or the greatest we found in ldap+1
	# NOTE:  Apparently the comparison does not support <, so <= is required.
	NEW_UID=2000
	FOUND_UID=$(ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount)(uidNumber>=2000)(uidNumber<=2999))" uidNumber | grep -E "^uidNumber:" | sort -n -r | head -1 | sed 's/uidNumber: //')
	if [[ $FOUND_UID =~ ^[0-9]+$ ]]; then
		if [ "$FOUND_UID" -ge "$NEW_UID" ]; then
			NEW_UID=$((FOUND_UID + 1))
		fi
	fi

	echo $NEW_UID
}

# ====================================
#  Parameters
# ====================================
#  1 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================	
ldapGetNextServiceUID() {

	# If the base_dn was passed, use it.
	local base_dn=$1

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Default first service ID is 3000.  We'll take it or the greatest we found in ldap+1
	# NOTE:  Apparently the comparison does not support <, so <= is required.
	NEW_UID=3000
	FOUND_UID=$(ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount)(uidNumber>=3000)(uidNumber<=3999))" uidNumber | grep -E "^uidNumber:" | sort -n -r | head -1 | sed 's/uidNumber: //')
	if [[ $FOUND_UID =~ ^[0-9]+$ ]]; then
		if [ "$FOUND_UID" -ge "$NEW_UID" ]; then
			NEW_UID=$((FOUND_UID + 1))
		fi
	fi

	echo $NEW_UID
}


# ====================================
#  Parameters
# ====================================
#  1 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetNextGID() {

	local base_dn=$1

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Default first group ID is 1000.  We'll take it or the greatest we found in ldap+1
	# NOTE:  Apparently the comparison does not support <, so <= is required.
	NEW_GID=1000
	FOUND_GID=$(ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)(gidNumber>=1000)(gidNumber<=1999))" gidNumber | grep -E "^gidNumber:" | sort -n -r | head -1 | sed 's/gidNumber: //')
	if [[ $FOUND_GID =~ ^[0-9]+$ ]]; then
		if [ "$FOUND_GID" -ge "$NEW_GID" ]; then
			NEW_GID=$((FOUND_GID + 1))
		fi
	fi

	echo $NEW_GID
}


# ======================================
#  Parameters
# ======================================
#  1 - Username to search for groups for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ======================================
ldapGetUserGroups() {

	local username=$1
	local base_dn=$2	

	# Make sure we have a username
	if ! [ -n "$username" ]; then
		echo "Expected username as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Search for the groups that the user is a member of:
	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)(memberUid=$username))" cn 2>/dev/null | grep -E "^cn:" | sed 's/cn: //g'
}


# ====================================
#  Parameters
# ====================================
#  1 - OU Name (Optional)
#  2 - Min UID (Optional)
#  3 - Max UID (Optional)
#  4 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetUsers() {

	local ou_name=$1
	local min_uid=$2
	local max_uid=$3
	local base_dn=$4

	# If the ou_name was passed, add it to the search filter:
	if [ -n "$ou_name" ]; then
		search_domain="ou=$ou_name,$base_dn"
	else
		search_domain="$base_dn"
	fi

	search_filter=""
	if [ -n "$min_uid" ]; then
		search_filter+="(uidNumber>=$min_uid)"
	fi

	if [ -n "$max_uid" ]; then
		search_filter+="(uidNumber<=$max_uid)"
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	ldapsearch -x -LLL -b "$search_domain" "(&(objectClass=posixAccount)$search_filter)" uid 2>/dev/null | grep -E "^uid:" | sed 's/uid: //g'
}



# ====================================
#  Parameters
# ====================================
#  1 - Min GID (Optional)
#  2 - Max GID (Optional)
#  3 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetGroups() {

	local min_gid=$1
	local max_gid=$2
	local base_dn=$3

	search_filter=""
	if [ -n "$min_gid" ]; then
		search_filter+="(gidNumber>=$min_gid)"
	fi

	if [ -n "$max_gid" ]; then
		search_filter+="(gidNumber<=$max_gid)"
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)$search_filter)" cn 2>/dev/null | grep -E "^cn:" | sed 's/cn: //g'
}


# ====================================
#  Parameters
# ====================================
#  1 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetOUs() {

	local base_dn=$1

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	ldapsearch -x -LLL -b "$base_dn" "(objectClass=organizationalUnit)" ou 2>/dev/null | grep -E "^ou:" | sed 's/ou: //g'
}


# ====================================
#  Parameters
# ====================================
#  1 - OU Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================	
ldapOUExists() {

	local ou_name=$1
	local base_dn=$2

	# Make sure we have an OU name
	if ! [ -n "$ou_name" ]; then
		echo "Expected an OU name as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Search for the OU
	result=$(ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=organizationalUnit)(ou=$ou_name))" ou 2>/dev/null)
	if [ -n "${result}" ]; then
		echo true
	else
		echo false
	fi
}

# ====================================
#  Parameters
# ====================================
#  1 - OU Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetOUMembers() {
	local ou_name=$1
	local base_dn=$2

	# Make sure we have an OU name
	if ! [ -n "$ou_name" ]; then
		echo "Expected an OU name as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	ldapsearch -x -LLL -b "ou=$ou_name,$base_dn" "(objectClass=posixAccount)" uid 2>/dev/null | grep -E "^uid:" | sed 's/uid: //g'	
}


# ====================================
#  Parameters
# ====================================
#  1 - OU Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetOUMemberCount() {
	local ou_name=$1
	local base_dn=$2

	# Make sure we have an OU name
	if ! [ -n "$ou_name" ]; then
		echo "Expected an OU name as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Search for the OU
	ldapsearch -x -LLL  -b "ou=$ou_name,$base_dn" -s sub "(objectclass=*)" dn | grep -c ^dn:
}


# ====================================
#  Parameters
# ====================================
#  1 - Username to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetUserDetail() {
	local username=$1
	local base_dn=$2

	# Make sure we have a username
	if ! [ -n "$username" ]; then
		echo "Expected a username as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi	

	# Search for the user's details
	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount)(uid=$username))"
}



# ====================================
#  Parameters
# ====================================
#  1 - Group Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetGroupDetail() {
	local group_name=$1
	local base_dn=$2

	# Make sure we have a group name
	if ! [ -n "$group_name" ]; then
		echo "Expected a group name as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Search for the group's details
	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup)(cn=$group_name))"
}



# ====================================
#  Parameters
# ====================================
#  1 - OU Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
ldapGetOUDetail() {
	local ou_name=$1
	local base_dn=$2

	# Make sure we have an OU name
	if ! [ -n "$ou_name" ]; then
		echo "Expected an OU name as the first parameter."
		exit 1
	fi

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi	

	# Search for the OU's details
	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=organizationalUnit)(ou=$ou_name))"
}



# ====================================
#  Parameters
# ====================================
#  1 - Returned value from a command
#      Typically $?.
#  2 - Result from the command
# ====================================
verifyResult() {
    local returned=$1
    local result=$2

	if [ "$returned" -ne 0 ]; then
		echo ""
		echo "------------------------------------------------------------------------"
		echo "                   E X E C U T I O N      F A I L E D"
		echo "------------------------------------------------------------------------"
		if [ -n "$result" ]; then
			echo "$result"
			echo "------------------------------------------------------------------------"
		fi	
		exit 1
	fi
}