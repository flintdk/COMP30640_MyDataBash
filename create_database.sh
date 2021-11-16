#!/bin/bash
# create_datebase.sh; Create a folder to contain all entities for a database

# First - check our arguments:
function usage() {
    # Function 'usage()'' expects two arguments.
    #   -> $1 the error status we will exit with
    #   -> $2 the error message to display

    # Formatting from: https://misc.flogisoft.com/bash/tip_colors_and_formatting
    #   echo -e "\e[1mbold\e[0m"
    #   echo -e "\e[3mitalic\e[0m"
    #   echo -e "\e[3m\e[1mbold italic\e[0m"
    #   echo -e "\e[4munderline\e[0m"
    #   echo -e "\e[9mstrikethrough\e[0m"
    echo -e "$2  \e[1mUsage\e[0m: \e[3m$0\e[0m \e[3mdatabase_name\e[0m"
    exit $1  # exit with error status
}
if [ -z "$1" ]; then
    usage 1 "ERROR You must supply a database name.";
elif [ $# -ne 1 ]; then
    usage 1 "ERROR The number of arguments is wrong.";
fi

# here the core of your script
database=$1

# If the database exists (we don't care if it's a regular file, or a directory,
# or whatever) - then this is an error and we abort
if [ -e "$database" ]; then
    echo -e "ERROR The database \e[1m$database\e[0m already exists!  Aborting..." >&2 # &2 is standard error output
    exit 2 # the exit code that shows the db already existed
else
    # at the end of the script an exit code 0 means everything went well
    mkdir "$database"
    echo -e "Success! The database \e[1m$database\e[0m has been created"
    exit 0
fi