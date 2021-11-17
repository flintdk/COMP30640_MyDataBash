#! /bin/bash
# V.sh; An atomic operation that releases the semaphore, waking up a waiting P (if any)
#       *** The signal() operation ***
if [ -z "$1" ]; then
    echo "Usage $1 mutex-name"
    exit 1
else
    rm "$1-lock"
    exit 0
fi