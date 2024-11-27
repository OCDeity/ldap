#!/bin/bash

REQUIRED_PARAMS=()
OPTIONAL_PARAMS=("BASE_DN")

source ./ldaplib.sh
source ./config.sh


# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


readarray -t users < <(ldapGetUsers "$BASE_DN")

echo "Users found in \"$BASE_DN\":"
for user in "${users[@]}"; do
	echo "$user"
done
