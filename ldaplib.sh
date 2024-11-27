#!/bin/bash


# ====================================
#  Parameters
# ====================================
#  None
# ====================================
function getBaseDNfromSearchDomain {
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
function getBaseDN {
	ldapsearch -x -s base -LLL -b "" namingContexts 2>/dev/null | grep -E "^namingContexts:" | sed 's/namingContexts: //g'
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
function ldapAdd {

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
function ldapModify {

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
#  1 - Username to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
function ldapUserExists {

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
#  1 - Group Name to search for
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
function ldapGetGroupDN {
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
function ldapGroupExists {

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
function ldapGetGroupDN {
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
function ldapGetUserDN {
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



# =====================================
#  Parameters
# =====================================
#  1 - Group Name to search for members
#  2 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# =====================================
function ldapGetMembers {
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
function ldapIsMember {
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
function ldapGetNextUID {

	local base_dn=$1

    # If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Default first user ID is 2000.  We'll take it or the greatest we found in ldap+1
	NEW_UID=2000
	FOUND_UID=$(ldapsearch -x -LLL -b "$base_dn" "(objectClass=posixAccount)" uidNumber | grep -E "^uidNumber:" | sort -n -r | head -1 | sed 's/uidNumber: //')
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
function ldapGetNextServiceUID {

	# If the base_dn was passed, use it.
	local base_dn=$1

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Default first service ID is 3000.  We'll take it or the greatest we found in ldap+1
	NEW_UID=3000
	FOUND_UID=$(ldapsearch -x -LLL -b "$base_dn" "(objectClass=posixAccount)" uidNumber | grep -E "^uidNumber:" | sort -n -r | head -1 | sed 's/uidNumber: //')
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
function ldapGetNextGID {

	local base_dn=$1

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	# Default first group ID is 1000.  We'll take it or the greatest we found in ldap+1
	NEW_GID=1000
	FOUND_GID=$(ldapsearch -x -LLL -b "$base_dn" "(objectClass=posixGroup)" gidNumber | grep -E "^gidNumber:" | sort -n -r | head -1 | sed 's/gidNumber: //')
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
function ldapGetUserGroups {

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
#  1 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
function ldapGetUsers {

	local base_dn=$1

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount))" uid 2>/dev/null | grep -E "^uid:" | sed 's/uid: //g'
}



# ====================================
#  Parameters
# ====================================
#  1 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
function ldapGetGroups {

	local base_dn=$1

	# If the base_dn was not passed, attempt to get it:
	if ! [ -n "$base_dn" ]; then
		base_dn=$(getBaseDN)
	fi

	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixGroup))" cn 2>/dev/null | grep -E "^cn:" | sed 's/cn: //g'
}


# ====================================
#  Parameters
# ====================================
#  1 - BaseDN (Optional)
#      If omitted, getBaseDN is called
# ====================================
function ldapGetOUs {

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
function ldapOUExists {

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

function ldapGetOUMembers {
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

	ldapsearch -x -LLL -b "$base_dn" "(&(objectClass=posixAccount)(ou=$ou_name))" ou 2>/dev/null | grep -E "^ou:" | sed 's/ou: //g'	
}


function ldapGetServices {
	local base_dn=$1

	ldapGetOUMembers "services" "$base_dn"
}
