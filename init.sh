#! /bin/bash

REQUIRED_PARAMS=("LDAP_PASSWORD")
source ./ldaplib.sh
source ./config.sh


# Get the LDAP Admin Password if we don't already have it.
getLDAPPassword LDAP_PASSWORD

# Create the standard OUs:
./createOU.sh --ou "groups" --ldap-password "$LDAP_PASSWORD"
./createOU.sh --ou "users" --ldap-password "$LDAP_PASSWORD"
./createOU.sh --ou "services" --ldap-password "$LDAP_PASSWORD"


# Create the standard groups:
./createGroup.sh --groupname "admin" --ldap-password "$LDAP_PASSWORD"
./createGroup.sh --groupname "media" --ldap-password "$LDAP_PASSWORD"


# Get the media GID for our upcoming service media-based services:
MEDIA_GID=$(ldapGetGroupID "media" "$BASE_DN")
verifyResult "$?" "$MEDIA_GID"

# Create our media-based services using the media GID as their primary group:
./createService.sh --servicename "sabnzbd" --new-gid "$MEDIA_GID" --ldap-password "$LDAP_PASSWORD"
./createService.sh --servicename "sonarr" --new-gid "$MEDIA_GID" --ldap-password "$LDAP_PASSWORD"
./createService.sh --servicename "radarr" --new-gid "$MEDIA_GID" --ldap-password "$LDAP_PASSWORD"



# ====================================
#       L X C   M A P P I N G S 
# ====================================

# Create our LXC mappings for the root user and its group:
./mapLxcUser.sh --username "root" --mapped-name "lxc-root" --new-uid "$LXC_OFFSET" --new-gid "$LXC_OFFSET" --ldap-password "$LDAP_PASSWORD"
./mapLxcGroup.sh --groupname "root" --mapped-name "lxc-root" --new-gid "$LXC_OFFSET" --ldap-password "$LDAP_PASSWORD"


# Map the media group:
./mapLxcGroup.sh --groupname "media" --ldap-password "$LDAP_PASSWORD"


# Map the media-based services:
./mapLxcService.sh --servicename "sabnzbd" --ldap-password "$LDAP_PASSWORD"
./mapLxcService.sh --servicename "sonarr" --ldap-password "$LDAP_PASSWORD"
./mapLxcService.sh --servicename "radarr" --ldap-password "$LDAP_PASSWORD"

