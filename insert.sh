#!/bin/bash
# insert.sh; Insert data into a database table (file)

# Set up home directory and include shared resources
home_dir="$(pwd)"
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
    echo -e "$2  \e[1mUsage\e[0m: \e[3m$0 database_name table_name data_tuple\e[0m"
    exit "$1"  # exit with error status
}
if [ -z "$1" ]; then
    usage 1 "ERROR You must supply a database name.";
elif [ -z "$2" ]; then
    usage 1 "ERROR You must supply a table name.";
elif [ -z "$3" ]; then
    usage 1 "ERROR You must supply a tuple with the data for insert.";
elif [ $# -ne 3 ]; then
    # msg="INSERT.SH: command line arguments are:"
    # for arg in "$@"; do
    #     msg+="\t>$arg<\n";
    # done
    # echo -e "$msg"
    usage 1 "ERROR The number of arguments is wrong.";
fi

# This script supports spaces in the database name, table name and tuple values
# NOTE: The script takes *3* arguments, so if spaces are required in tuple
#       values, for e.g. it's important the argumnents are quoted.  E.g:
#  insert.sh "bob the builder" "can he fix it" "bob the builder,yes he Can"
database="$1"
table="$2"
tuple="$3"

# If the database does not exist...
if [ ! -d "$data_dir/$database" ]; then
    echo -e "ERROR The database \e[1m$database\e[0m does not exist!  Aborting..." >&2 # &2 is standard error output
    exit 2 # the exit code that shows the db does not exist
# If the table does not exist...
elif [ ! -e "$data_dir/$database/$table" ]; then
    echo -e "ERROR The table \e[1m$table\e[0m does not exist!  Aborting..." >&2 # &2 is standard error output
    exit 3 # the exit code that shows the table does not exist
fi

# We establish how many columns are in our table header.
noDelimsInTableHeader=$(head -n 1 "$data_dir/$database/$table" | grep -o ","  | wc -l)
noColsInTable=$(( noDelimsInTableHeader + 1))
# We establish how many columns are in our data tuple.
noDelimsInTuple=$(echo "$tuple" | grep -o "," | wc -l)
noColsInTuple=$(( noDelimsInTuple + 1))

if (( noColsInTuple != noColsInTable )); then
    err_msg="ERROR The table \e[1m$table\e[0m has $noColsInTable columns.\n"
    err_msg+="The data tuple supplied has $noColsInTuple attributes?\n"
    err_msg+="Mismatch! Aborting..."
    echo -e "$err_msg" >&2 # &2 is standard error output
    exit 3 # the exit code that shows the db alreadys existed
else
    # We only lock the database table for as long as it takes us to insert
    # a record to it...
    getLock_P "$data_dir/$database/$table"
    # at the end of the script an exit code 0 means everything went well
    echo "$tuple" >> "$data_dir/$database/$table"
    # tuple written, release the lock
    releaseLock_V "$data_dir/$database/$table"
    echo -e "OK: Tuple Inserted."
    exit 0
fi