#!/bin/bash
# server.sh; Reads commands from clients and executes them

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
    echo -e "$2  \n\e[1mUsage\e[0m:"
    errMsg="\e[3m$0 [create_database | create_table | insert | select | shutdown]\e[0m\n"
    errMsg+="  \e[3mcreate_database database_name\e[0m\n"
    errMsg+="  \e[3mcreate_table database_name table_name columns_name\e[0m\n"
    errMsg+="  \e[3minsert database_name table_name data_tuple\e[0m\n"
    errMsg+="  \e[3mselect database_name table_name [ columns ]\e[0m\n"
    errMsg+="            \e[3m[ WHERE where_comparison_column where_comparison_value\e[0m\n"
    errMsg+="  \e[3mshutdown\e[0m\n"
    echo -e "$errMsg"
    #
    # For our mission-critical server process, we don't exit if there's a bad
    # request. We just log it and continue. Given the command-line nature of
    # this application, aborting seems overkill!
    exit $1  # exit with error status
}
mode=""
interactive="INTERACTIVE"
if [ -z "$1" ]; then
    echo "Running as a service.  Input from the keyboard ignored.";
elif [ "$1" == "$interactive" ]; then
    echo "Running in INTERACTIVE mode.  Commands from the keyboard processed.";
    mode="$1"
else
    usage 1 "ERROR: Expected \"INTERACTIVE\" or no arguments, encountered \"$1\""
fi

#===============================================================================
#===============================================================================

function shutdownServer() {
    # shutdownServer; Shut down the server.
    shutdownMsg="$1 Orderly Server Shutdown requested.  Bye!"
    if [ "$mode" == "$interactive" ]; then
        echo "$shutdownMsg"
    else
        echo "$shutdownMsg" > "$userId.pipe"
    fi
    tidyPipe "$1" "$2"
    exit 0
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    shutdownServer "CTRL-C" "server.pipe"
    exit 1
}


#===============================================================================
#===============================================================================

# If we're not in INTERACTIVE mode, then before we enter our management loop,
# create our command pipe
if [ ! "$mode" == "$interactive" ]; then
    mkfifo server.pipe
fi

# Infinite server loop - only exits on command.
while true; do
    if [ "$mode" == "$interactive" ]; then
        echo -n "Please enter a server command: ";
        #read -r command;
        #old_ifs="$IFS"
        #IFS=' ' read -r -a commandArr
        #IFS="$old_ifs"  # Reset IFS so I haven't broken anything...
        read -r -a commandArr

        # -> In INTERACTIVE mode our commands will be the base commands
    else
        # In 'service' mode we read server commands from the server.pipe pipe
        read -r -a commandArr < server.pipe

        # -> In 'Service' mode our commands will have a UserId first, followed by
        #    the base commands.  Grab out the user id...
        userId="${commandArr[0]}"
        echo "userid is $userId"

        # Then remove the first element of the array...
        # Use a new method (to me) to remove the first element from the array. See:
        #   https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
        # See the section starting with 'If parameter is an indexed array name
        # subscripted by ‘@’ or ‘*’, the result...'
        # This neat little syntax lets me extract whatever array elements I want!
        #unset commandArr[0]
        commandArr=("${commandArr[@]:1}")  # Remove the userId from the array
    fi

    # Whether interactive or service mode, now grab the server command...
    srvrCommand="${commandArr[0]}"
    echo "srvrCommand is $srvrCommand"
    argArr=("${commandArr[@]:1}")  # ... and then remove it from the array too...
    msg="server.sh function arguments are:"
    for fnArg in "${argArr[@]}"; do
        msg+=" >$fnArg<";
    done
    echo "$msg"

    case "$srvrCommand" in
    create_database)
        # create_database $database: creates database $database
        if [ "$mode" == "$interactive" ]; then
            "$home_dir/create_database.sh" "${argArr[@]}" > "$home_dir/create_database.log" 2>&1 &
        else
            "$home_dir/create_database.sh" "${argArr[@]}" > "$userId.pipe" 2>&1 &
        fi
        ;;
    create_table)
        # create table $database $table: which creates table $table
        if [ "$mode" == "$interactive" ]; then
            "$home_dir/create_table.sh" "${argArr[@]}" > "$home_dir/create_table.log" 2>&1 &
        else
            "$home_dir/create_table.sh" "${argArr[@]}" > "$userId.pipe" 2>&1 &
        fi
        ;;
    insert)
        # insert $database $table tuple: insert the tuple into table $table of database $database
        if [ "$mode" == "$interactive" ]; then
            "$home_dir/insert.sh" "${argArr[@]}" > "$home_dir/insert.log" 2>&1 &
        else
            "$home_dir/insert.sh" "${argArr[@]}" > "$userId.pipe" 2>&1 &
        fi
        
        ;;
    select)
        # select $database $table tuple: display the columns from table $table of database $database
        if [ "$mode" == "$interactive" ]; then
            "$home_dir/select.sh" "${argArr[@]}" > "$home_dir/select.log" 2>&1 &
        else
            "$home_dir/select.sh" "${argArr[@]}" > "$userId.pipe" 2>&1 &
        fi
        ;;
    shutdown)
        # shutdown: exit with a return code of 0
        if [ "$mode" == "$interactive" ]; then
            shutdownServer "SERVER.SH" "server.pipe"
        else
            shutdownServer "SERVER.SH" "server.pipe" > "$userId.pipe" 2>&1
        fi
        ;;
    *)
        errMsg="ERROR: Bad server command. I don't understand -> \"$srvrCommand\"";
        errMsg+="Ignoring, logging and listening for more commands!";
        if [ "$mode" == "$interactive" ]; then
            echo "$errMsg"
        else
            echo "$errMsg" > "$userId.pipe"
        fi
    esac
done

# Parting note:  There is a ton of repetition in this script. It's littered with
# "if interactive, else..." logic.  I could have added a layer (file? another
# pipe?) and allowed the server to always write all content there.  Then at the
# end of a command choose where to sent the output.
#
# But I guess I don't have time for that so...