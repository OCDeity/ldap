#! /bin/bash

source ./config.sh
source ./ldaplib.sh

# Get the base DN if it's not already set
if [ -z "$BASE_DN" ]; then
    BASE_DN=$(getBaseDN)
fi


readarray -t users < <(ldapGetUsers "$BASE_DN")

echo "Users in $BASE_DN:"
for user in "${users[@]}"; do
	echo "$user"
done
