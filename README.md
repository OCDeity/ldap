# ldap
A group of simple bash scripts for manipulating ldap users and groups in order to provide consistency in our environment.

## Sturctural Overview
These scripts are designed to be run on the LDAP server itself.  They call functions from the `ldaplib.sh` library for all LDAP operations. Various templates are used for the ldap modifications and stored in the `templates` directory.  The output of templates used for user, group, and service creation are stored in respective directories by default.  `config.sh` is used as a common place for the definition of variable defaults, parameter parsing and help output.

## Prerequisites
- OpenLDAP server
- A user with admin access to the LDAP server
- The LDAP admin password

## Initial Setup
The `init.sh` script:
- Verifies the paths to the templates and the output directories
- Creates the expected Organizational Units (`users`, `groups` and `services`)
Optionally:
- Creates a list of groups (currently empty)
- Creates a list of service users (currently empty)
- Creates a "mapping" for a root LXC user. (currently disabled)

## Service Users
Service users are intended to be used only on a local server.  They created under a `services` OU and cannot log in.

## LXC Useage
LXC stands for Linux Containers and can be used by Prxomox.  When an LXC is created, host directories can be mapped into the container.  There is a mapping of UID and GID that takes place for security purposes.  For example, if a user with UID 1000 creates a file in a mapped directory from within a container, outside the container that file will be owned by UID 101000.  Our use of the "mapping" is to create matching users in LDAP for readability outside of the container.  The "mapped" service is intended to have no permissions, but will show up as "lxc-<service-name>" on file permissions outside of the container.
