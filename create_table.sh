#!/bin/bash
# create_table.sh; Create a file representing a table in a database

# Set up home directory and include shared resources
home_dir=$(pwd)
# shellcheck source=./dbutils.sh
source "$home_dir/dbutils.sh"

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
    echo -e "$2  \e[1mUsage\e[0m: \e[3m$0\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3mcolumns_name\e[0m"
    exit $1  # exit with error status
}
if [ -z "$1" ]; then
    usage 1 "ERROR You must supply a database name.";
elif [ -z "$2" ]; then
    usage 1 "ERROR You must supply a table name.";
elif [ -z "$3" ]; then
    usage 1 "ERROR You must supply the table column headings.";
elif [ $# -ne 3 ]; then
    usage 1 "ERROR The number of arguments is wrong.";
fi

# here the core of your script
database=$1
table=$2
columns=$3

# If the database does not exist...
if [ ! -d "$home_dir/$database" ]; then
    echo -e "ERROR The database \e[1m$database\e[0m does not exist!  Aborting..." >&2 # &2 is standard error output
    exit 2 # the exit code that shows the db does not exist
fi

# Create a lock at table level before checking/creating a table
getLock_P "$database/$table"
# If the table aready exists...
if [ -e "$home_dir/$database/$table" ]; then
    echo -e "ERROR The table \e[1m$table\e[0m already exists!  Aborting..." >&2 # &2 is standard error output
    # If the table already exists, we need to exit.  Don't forget to release the lock!
    releaseLock_V "$database/$table"
    exit 3 # the exit code that shows the table already existed    
else
    # at the end of the script an exit code 0 means everything went well
    touch "$home_dir/$database/$table"
    # Write the desired columns to the newly created file.
    echo "$columns" > "$home_dir/$database/$table"
    # Table created and columns written - release the lock
    releaseLock_V "$database/$table"
    echo -e "Success! The table \e[1m$table\e[0m has been created, for database \e[1m$database\e[0m"
    exit 0
fi