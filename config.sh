#!/bin/bash

# Variables & defaults:
BASE_DN=

# Paths:
TEMPLATE_PATH=./templates/
USER_LDIF_PATH=./users/
GROUP_LDIF_PATH=./groups/
SERVICE_LDIF_PATH=./services/

# Name Related:
USERNAME=
SERVICENAME=
GROUPNAME=
OU_NAME=
MAPPED_NAME=

# Password Related:
PASSWORD_HASH=
LDAP_PASSWORD=

# ID Number Related:
NEW_UID=
NEW_GID=

LXC_OFFSET=100000



function handle_usage {
    echo ""
    echo "Usage: $1 [options]"
    echo "Required (may be prompted if not provided):"
    if [ ${#REQUIRED_PARAMS[@]} -gt 0 ]; then
        handle_show_options "${REQUIRED_PARAMS[@]}"
    else
        echo "  None"
    fi
    echo ""
    echo "Optional:"
    if [ ${#OPTIONAL_PARAMS[@]} -gt 0 ]; then
        handle_show_options "${OPTIONAL_PARAMS[@]}"
    else
        echo "  None"
    fi
}

function handle_show_options {
    for item in "$@"; do
        case $item in
            "BASE_DN")
                echo "  --base-dn <base dn>        The base DN to use for the ldap access."
                ;;
            "TEMPLATE_PATH")
                echo "  --template-path <path>     The path to the template files."
                ;;
            "USER_LDIF_PATH")
                echo "  --user-ldif-path <path>    The output path for user .ldif files."
                ;;
            "GROUP_LDIF_PATH")
                echo "  --group-ldif-path <path>   The output path for group .ldif files."
                ;;
            "SERVICE_LDIF_PATH")
                echo "  --service-ldif-path <path> The output path for service .ldif files."
                ;;
            "USERNAME")
                echo "  --username <name>          The username for the user."
                ;;
            "GROUPNAME")
                echo "  --groupname <name>         The group name."
                ;;
            "SERVICENAME")
                echo "  --servicename <name>       The service name."
                ;;
            "MAPPED_NAME")
                echo "  --mapped-name <name>       The mapped name."
                ;;
            "OU_NAME")
                echo "  --ou <name>                The organizational unit's name."
                ;;
            "NEW_GID")
                echo "  --new-gid <gid>            The new group ID."
                ;;
            "NEW_UID")
                echo "  --new-uid <uid>            The new user ID."
                ;;
            "PW_HASH")
                echo "  --password-hash <hash>     The password hash for the given user."
                ;;
            "LDAP_PASSWORD")
                echo "  --ldap-password <pass>     The password for the ldap access."
                ;;
            *)
                echo "Unknown option: $item"
                ;;
        esac
    done
}






# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in

        # Base DN:
        --base-dn)
            BASE_DN="$2"
            shift # past argument
            shift # past value
            ;;

        # Paths:
        --template-path)
            TEMPLATE_PATH="$2"
            shift # past argument
            shift # past value
            ;;
        --user-ldif-path)
            USER_LDIF_PATH="$2"
            shift # past argument
            shift # past value
            ;;
        --group-ldif-path)
            GROUP_LDIF_PATH="$2"
            shift # past argument
            shift # past value
            ;;
        --service-ldif-path)
            SERVICE_LDIF_PATH="$2"
            shift # past argument
            shift # past value
            ;;


        # Name Related:
        --username)
            USERNAME="$2"
            shift # past argument
            shift # past value
            ;;
        --groupname)
            GROUPNAME="$2"
            shift # past argument
            shift # past value
            ;;
        --servicename)
            SERVICENAME="$2"
            shift # past argument
            shift # past value
            ;;
        --ou)
            OU_NAME="$2"
            shift # past argument
            shift # past value
            ;;
        --mapped-name)
            MAPPED_NAME="$2"
            shift # past argument
            shift # past value
            ;;

        # ID Number Related:
        --new-gid)
            NEW_GID="$2"
            if ! [[ "$NEW_GID" =~ ^[0-9]+$ ]]; then
                echo "The new-gid parameter must be a number."
                exit 1
            fi
            shift # past argument
            shift # past value
            ;;
        --new-uid)
            NEW_UID="$2"
            if ! [[ "$NEW_UID" =~ ^[0-9]+$ ]]; then
                echo "The new-uid parameter must be a number."
                exit 1
            fi
            shift # past argument
            shift # past value
            ;;


        # Password related:
        --password-hash)
            PW_HASH="$2"
            shift # past argument
            shift # past value
            ;;
        --ldap-password)
            LDAP_PASSWORD="$2"
            shift # past argument
            shift # past value
            ;;

        --help)
            handle_usage "$0" 
            exit 0
            ;;
        *)
            echo ""
            echo "Unexpected parameter passed: $1"
            handle_usage "$0"
            exit 0
            ;;
    esac
done


