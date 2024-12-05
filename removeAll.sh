#!/bin/bash

source ./ldaplib.sh
source ./config.sh

echo ""
echo "======================================"
echo "  INTENDED FOR DEVELOPMENT USE ONLY"
echo "======================================"
echo " This will remove predefined LXC "
echo " mappings, users, groups, and OUs."
echo "======================================"
echo ""

# Get the LDAP Admin Password if we don't already have it.
getLDAPPassword LDAP_PASSWORD

# Remove the LXC Mapped Users:
./removeUser.sh --username "lxc-root" --ldap-password "$LDAP_PASSWORD"
./removeUser.sh --username "lxc-sabnzbd" --ldap-password "$LDAP_PASSWORD"
./removeUser.sh --username "lxc-sonarr" --ldap-password "$LDAP_PASSWORD"
./removeUser.sh --username "lxc-radarr" --ldap-password "$LDAP_PASSWORD"

# Remove the LXC Mapped Groups:
./removeGroup.sh --groupname "lxc-root" --ldap-password "$LDAP_PASSWORD"
./removeGroup.sh --groupname "lxc-media" --ldap-password "$LDAP_PASSWORD"

# Remove the Users:
./removeUser.sh --username "kopper" --ldap-password "$LDAP_PASSWORD"

# Remove the Services:
./removeUser.sh --username "sabnzbd" --ldap-password "$LDAP_PASSWORD"
./removeUser.sh --username "sonarr" --ldap-password "$LDAP_PASSWORD"
./removeUser.sh --username "radarr" --ldap-password "$LDAP_PASSWORD"

# Remove the Groups:
./removeGroup.sh --groupname "media" --ldap-password "$LDAP_PASSWORD"
./removeGroup.sh --groupname "admin" --ldap-password "$LDAP_PASSWORD"

# Remove the OUs:
./removeOU.sh --ou "services" --ldap-password "$LDAP_PASSWORD"
./removeOU.sh --ou "groups" --ldap-password "$LDAP_PASSWORD"
./removeOU.sh --ou "users" --ldap-password "$LDAP_PASSWORD"
