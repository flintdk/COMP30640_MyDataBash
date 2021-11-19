#!/bin/bash
# client.sh; Reads commands from clients and executes them

# Set up home directory...
home_dir=$(pwd)

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
    echo -e "$2\n\e[1mUsage\e[0m:"
    errMsg="\e[3m$0\e[0m \e[3muser_id\e[0m\n"
    errMsg+="Client Commands Processed:\n"
    errMsg+="  \e[3mcreate_database\e[0m \e[3mdatabase_name\e[0m\n"
    errMsg+="  \e[3mcreate_table\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3mcolumns_name\e[0m\n"
    errMsg+="  \e[3minsert\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3mdata_tuple\e[0m\n"
    errMsg+="  \e[3mselect\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3m[ columns ]\e[0m\n"
    errMsg+="            \e[3m[ WHERE where_comparison_column where_comparison_value ]\e[0m\n"
    errMsg+="  \e[3mshutdown\e[0m - Shut down the remote server\n"
    errMsg+="  \e[3mexit\e[0m - Shut down this client\n"
    echo -e "$errMsg"
    #
    # For our mission-critical server process, we don't exit if there's a bad
    # request. We just log it and continue. Given the command-line nature of
    # this application, aborting seems overkill!
    exit "$1"  # exit with error status
}
if [ -z "$1" ]; then
    usage 1 "ERROR You must supply a UserId.";
fi
usage 1 "testing client.sh"
#===============================================================================
#===============================================================================

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    #do something when control c is trapped

    delete client  pipe
    echo "ctrl_c"
    exit 1
}

#===============================================================================
#===============================================================================

# Before we enter our management loop, create our command pipe
mkfifo "$1.pipe"

# Infinite client loop - only exits on command.
while true; do
    echo -n "Please enter a server command: ";
    read -r -a commandArr

If the request is well formed, then the script prints req $id args with $id
being the id given as parameter of the client.sh script.

    # We now have an array consisting of the users commands.
    clientCommand="${commandArr[0]}"
    # Remove the first element from the array now it's consumed.
    commandArr=("${commandArr[@]:1}")  # we'll be passing all remaining arguments to the server

    case "$clientCommand" in
    create_database)
        # create_database $database: creates database $database
        "$home_dir/create_database.sh" "${commandArr[@]}" > "$home_dir/create_database.log" 2>&1 &
        ;;
    create_table)
        # create table $database $table: which creates table $table
        "$home_dir/create_table.sh" "${commandArr[@]}" > "$home_dir/create_table.log" 2>&1 &
        ;;
    insert)
        # insert $database $table tuple: insert the tuple into table $table of database $database
        "$home_dir/insert.sh" "${commandArr[@]}" "$home_dir/insert.log" 2>&1 &
        ;;
    select)
        # select $database $table tuple: display the columns from table $table of database $database
        "$home_dir/select.sh" "${commandArr[@]}" "$home_dir/select.log" 2>&1 &
        ;;
    shutdown)
        # shutdown: exit with a return code of 0
        echo "CLIENT.SH Orderly Server Shutdown requested."
        ;;
    exit)
        # shutdown: exit with a return code of 0
        echo "CLIENT.SH Client Shutdown requested.  Bye!"
        if [ -p "$1.pipe" ]; then
            rm "$1.pipe"
        fi
        exit 0
        ;;
    *)
        errMsg="ERROR: Bad client command. I don't understand -> \"$clientCommand\"";
        errMsg+="Ignoring, logging and listening for more commands!";
        echo "$errMsg"
    esac
done