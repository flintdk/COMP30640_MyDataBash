#!/bin/bash

# $1 = lock/release
# $2 = db name
# $3 = table name

# Set up home directory and include shared resources
home_dir="$(pwd)"
# shellcheck source=./dbutils.sh
source "$home_dir/dbutils.sh"

# Use $1 as the db name
if [ "$1" == "lock" ]; then
    getLock_P "$data_dir/$2/$3"
else
    releaseLock_V "$data_dir/$2/$3"
fi