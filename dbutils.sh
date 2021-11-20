#!/bin/bash
# dbutils.sh; Function, etc. library for the amazing Database Server

home_dir=$(pwd)
data_dir=$home_dir/data

function tidyPipe() {
    # tidyPipe; A generic function to clean up pipe when we're done with them
    #           and print an error message.

    # I have implemented no argument checking!! How much do I trust myself...
    echo -e "$1: Cleaning up pipe '$2'"
    if [ -p "$2" ]; then
        rm "$home_dir/$2"
    fi
}

function getLock_P() {
    # getLock_P; An atomic operation that waits for semaphore to become available, then takes it
    #            *** The wait() operation ***
    if [ -z "$1" ]; then
        echo "Usage $0 mutex-name"
        return 1
    else
        # Use the P.sh script itself to link to - we know this file always exist
        while ! ln "$0" "$1-lock" 2>/dev/null; do
            sleep 1
        done
        return 0
    fi
}

function releaseLock_V() {
    # releaseLock_V; An atomic operation that releases the semaphore, waking up a waiting P (if any)
    #                *** The signal() operation ***
    if [ -z "$1" ]; then
        echo "Usage $1 mutex-name"
        return 1
    else
        rm "$1-lock"
        return 0
    fi
}