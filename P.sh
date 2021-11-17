#! /bin/bash
# P.sh; An atomic operation that waits for semaphore to become available, then takes it
#       *** The wait() operation ***

if [ -z "$1" ]; then
    echo "Usage $0 mutex-name"
    exit 1
else
    # Use the P.sh script itself to link to - we know this file always exist
    while ! ln "$0" "$1-lock" 2>/dev/null; do
        sleep 1
    done
    exit 0
fi