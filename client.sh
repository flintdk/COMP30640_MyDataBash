#!/bin/bash
# client.sh; Reads commands from clients and executes them

# Set up home directory and include shared resources
home_dir=$(pwd)
# shellcheck source=./dbutils.sh
source "$home_dir/dbutils.sh"

# Helper function - save me keying command summary twice, ensures consistancy in
# user docs (such as they are)
function echoCommandDocs() {
    cmdMsg="Client Commands Processed:\n"
    cmdMsg+="  \e[3mcreate_database\e[0m \e[3mdatabase_name\e[0m\n"
    cmdMsg+="  \e[3mcreate_table\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3mcolumns_name\e[0m\n"
    cmdMsg+="  \e[3minsert\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3mdata_tuple\e[0m\n"
    cmdMsg+="  \e[3mselect\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3m[ columns ]\e[0m\n"
    cmdMsg+="            \e[3m[ WHERE where_comparison_column where_comparison_value ]\e[0m\n"
    cmdMsg+="  \e[3mshutdown\e[0m - Shut down the remote server\n"
    cmdMsg+="  \e[3mexit\e[0m - Shut down this client"
    echo -e "$cmdMsg"
}

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
    echo -e "\e[3m$0\e[0m \e[3muser_id\e[0m"
    echoCommandDocs
    #
    # For our mission-critical server process, we don't exit if there's a bad
    # request. We just log it and continue. Given the command-line nature of
    # this application, aborting seems overkill!
    exit "$1"  # exit with error status
}
if [ -z "$1" ]; then
    usage 1 "ERROR You must supply a UserId.";
fi

#===============================================================================
#===============================================================================

function shutdownClient() {
    # shutdownServer; Shut down the server.
    echo "$1: Orderly Client Shutdown requested.  Bye!"
    tidyPipe "$1" "$2"
    exit 0
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    shutdownClient "CTRL-C" "$userId.pipe"
    exit 1
}


#===============================================================================
#===============================================================================

# Before we enter our management loop, create our command pipe
userId="$1"  # This does nothing, but does make code below easier to read.
if [ ! -e "$userId.pipe" ]; then
    mkfifo "$userId.pipe"
else
    echo "ERROR: Client Pipe (\"$userId.pipe\") already exists! Aborting..."
    exit 1
fi


# Infinite client loop - only exits on command.
while true; do
    echo ""
    echo -n "Please enter a command to send to the server ('help' for more): ";
    read -r -a commandArr

    # We now have an array consisting of the users commands.
    clientCommand="${commandArr[0]}"
    # Remove the first element from the array now it's consumed.
    argArr=("${commandArr[@]:1}")  # we'll be passing all remaining arguments to the server

    # Per the specification, if the request is well formed, then we print out:
    #   -> req $id args
    # ...with $id being the id given as parameter of the client.sh script.
    # (use brace expansion to list out the remaining arguments)
    echo "$clientCommand $userId" "${argArr[@]}"

    # NOTE: I am fully aware that there is repetition below.  I could validate
    #       the clientCommand by, for example, listing valid commands in an array
    #       and checking the received command is in the array.
    #       However: there are only four commands. The below is SUPER easy to
    #       read.  So I've left it as is.
    validServerCommand=false
    case "$clientCommand" in
    create_database)
        # create_database $database: creates database $database
        echo "$userId create_database " "${argArr[@]}" > "server.pipe"
        validServerCommand=true
        ;;
    create_table)
        # create table $database $table: which creates table $table
        echo "$userId create_table " "${argArr[@]}" > "server.pipe"
        validServerCommand=true
        ;;
    insert)
        # insert $database $table tuple: insert the tuple into table $table of database $database
        echo "$userId insert " "${argArr[@]}" > "server.pipe"
        validServerCommand=true
        ;;
    select)
        # select $database $table tuple: display the columns from table $table of database $database
        echo "$userId select " "${argArr[@]}" > "server.pipe"
        validServerCommand=true
        ;;
    shutdown)
        # shutdown: exit with a return code of 0
        echo "$userId shutdown " "${argArr[@]}" > "server.pipe"
        validServerCommand=true
        ;;
    help)
        # help: print a list of supported commands
        echo ""
        echoCommandDocs
        ;;
    exit)
        # shutdown: exit with a return code of 0
        shutdownClient "CLIENT.SH" "$userId.pipe"
        ;;
    *)
        errMsg="ERROR: Bad client command. I don't understand -> \"$clientCommand\"";
        errMsg+="Ignoring, logging and listening for more commands!";
        echo "$errMsg"
    esac

    # We've now sent our command to the server.  It's essential that we read
    # the reply pipe.  In bash, pipes are blocking.  So if the server writes a
    # reply to this clients result pipe, the server will be blocked indefinitely
    # until something on this end consumes the pipe!!
    if [ $validServerCommand == true ]; then
        # No point reading a server reply unless we've issued a valid command
        case "$clientCommand" in
        select)
            # With select, what has to be printed on the terminal is everything
            # after the first word ('start result') until the keyword 'end result'
            # For sed:
            # 1 = first line, d = delete, ; is the cmd separator, $ = last line
            sed '1d;$d' "$home_dir/$userId.pipe"
            ;;
        *)
            # create table $database $table: which creates table $table
            #read -r reply < "$userId.pipe"
            #echo "$reply"
            #cat "$home_dir/$userId.pipe"
            cat "$home_dir/$userId.pipe"
            ;;
        esac
    fi
done