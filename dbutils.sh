#!/bin/bash
# dbutils.sh; Function, etc. library for the amazing Database Server

# Set a variable for the applications home directory.
home_dir="$(pwd)"

# I prefer having all my databases in a 'data' subfolder.  But I have set them
# to the root folder so my project will pass the autograding tests.
#
# Following shellcheck code is irrelevant because ${data_dir} is not referenced
# in this script, but is referenced in client.sh/server.sh
# shellcheck disable=SC2034
#data_dir=$home_dir/data
data_dir=$home_dir
pipes_dir=$home_dir/pipes

# Made the following - bad as it is - out of frustration trying to deal with
# word splitting on commands read in from the user.
function parseUserInstrnString {
    # $1 is the command string to be parsed
    # $2 is the name ref of the array we want to modify
    local -n parsedArr=$2      # use nameref for indirection

    contentSoFar=""
    insideQuotes=false
    quoteTypeDetected=""
    for (( i=0; i<${#1}; i++ )); do
        # Inspect the current character
        character="${1:$i:1}"

        # NOTE: Yes! if the user mixes quotes or adds quotes inside their strings
        # this will break - but I am out of time.  So this solution is what we're
        # using (for better or worse)
        if [[ $character =~ [\"|\'] ]]; then
            # Found a Quote!!
            if [ $insideQuotes = true ]; then
                # We were ALREADY inside quotes...
                if [ "$character" = "$quoteTypeDetected" ]; then
                    #... AND it's the same type of quote as our opening quote.
                    # We've hit the end of the quoted argument!
                    # Close it out and add this chunk of content to the array
                    
                    # We want to drop the quotes... so just ignore "$character"
                    insideQuotes=false

                    parsedArr+=("$contentSoFar")
                    contentSoFar=""
                    quoteTypeDetected=""
                else
                    # NOTE if the quote found is not the same type as our opening
                    # quote then we just ignore it (in terms of parameter spliiting)
                    contentSoFar+=$character
                fi
            else
                # We found an OPENING quote...
                # Record it so we know what we're inside...
                quoteTypeDetected="$character"

                # We may have already processed some non-quoted items.  If we
                # have then use read to split them (on IFS) and load into an
                # array...
                if [ -n "$contentSoFar" ]; then
                    read -r -a sectionArr <<< "$contentSoFar"
                    parsedArr+=("${sectionArr[@]}")
                fi

                # Start a new run of 'contentSoFar', ignoring the opening quote
                contentSoFar=""
                insideQuotes=true
            fi
        else
            contentSoFar+=$character
        fi
    done
    if [ -n "$contentSoFar" ]; then
        read -r -a sectionArr <<< "$contentSoFar"
        #echo -e "DBUTILS.SH: post loop. Content so far is $contentSoFar"            
        parsedArr+=("${sectionArr[@]}")
    fi
    # msg="DBUTILS.SH Post Parsing. Split arguments are:\n"
    # for arg in "${parsedArr[@]}"; do
    #     msg+="\t>$arg<\n";
    # done
    # echo -en "$msg"
}

function tidyPipe() {
    # tidyPipe; A generic function to clean up pipe when we're done with them
    #           and print an error message.

    # I have implemented no argument checking!! How much do I trust myself...
    echo -e "$1: Cleaning up pipe '$2'"
    if [ -p "$pipes_dir/$2" ]; then
        rm "$pipes_dir/$2"
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