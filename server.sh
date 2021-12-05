#!/bin/bash
# server.sh; Reads commands from clients and executes them

# Set up home directory and include shared resources
home_dir="$(pwd)"
# shellcheck source=./dbutils.sh
source "$home_dir/dbutils.sh"

# Helper function - save me keying command summary twice, ensures consistancy in
# user docs (such as they are)
function echoServerCommandDocs() {
    cmdMsg="Server Commands Accepted:\n"
    cmdMsg+="  \e[3mhelp\e[0m - See this help text\n"
    cmdMsg+="  \e[3mcreate_database \"database_name\"\e[0m\n"
    cmdMsg+="  \e[3mcreate_table \"database_name\" \"table_name\" \"columns_list\"\e[0m\n"
    cmdMsg+="  \e[3minsert \"database_name\" \"table_name\" \"data_tuple\"\e[0m\n"
    cmdMsg+="  \e[3mselect \"database_name\" \"table_name\" [ column,numbers,separated,by,commas ]\e[0m\n"
    cmdMsg+="            \e[3m[ WHERE comparison_column_number \"comparison_value\"\e[0m\n"
    cmdMsg+="  \e[3mserver_shutdown\e[0m\n"
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
    echo -e "$2 \n\e[1mUsage\e[0m:"
    echo -e "\e[3m$0\e[0m \e[3m[ INTERACTIVE ]\e[0m"
    echo -e "Aborting..."
    #echoServerCommandDocs  # Not sure whether to include this here........
    #
    # For our mission-critical server process, we don't exit if there's a bad
    # request. We just log it and continue. Given the command-line nature of
    # this application, aborting seems overkill!
    exit "$1"  # exit with error status
}

# Use ps to see if we're running in the foreground or in the background...
# -o format   Means "in a User-defined format."
# format is a single argument in the form of a blank-separated or comma-separated list
# and offers a way to specify individual output columns.
# 'stat' means multi-character process state.
# According to the list of PROCESS STATE CODES '+' means in the foreground process group
serverProcess=""
foreground="foreground"
background="background"
ps -o stat= -p $$ >> "$home_dir/testing.log" 2>&1 &
# For command ps, 'stat' means multi-character process state (See ps PROCESS STATE CODES)
case $(ps -o stat= -p $$) in
  *+*) serverProcess="$foreground" ;;
  *) serverProcess="$background" ;;
esac
#echo "SERVER.SH:  I have detected I am running in the $serverProcess."

# The server as configured can run:
# -> In the background, running as a 'service' listening on the server pipe
# -> In the foreground, running as a 'service' listening on the server pipe
# -> In the foreground, running as an interactive server, accepting commands
#    from the keyboard.
mode=""
interactive="INTERACTIVE"
if [ $# -gt 1 ]; then
    msg="ERROR The number of arguments is wrong. Encountered:\n"
    for arg in "$@"; do
        msg+="\t$arg\n";
    done
    usage 1 "$msg"
elif [ -z "$1" ] || [ "$serverProcess" = "$background" ] ; then
    # If there's no command line argument -OR- we're running in the background
    # (regardless of any command line argument) then... we're running "as a service"
    # (i.e. listening to the pipe for commands)
    if [ "$serverProcess" = "$foreground" ]; then
        msg="Running as a service (listening on server.pipe) on this terminal.\n";
        msg+="Input from the keyboard ignored!";
        echo -e "$msg";
    fi
elif [ "$1" == "$interactive" ]; then
    clear
    mode="$1"
    msg="Running in INTERACTIVE mode.\n"
    msg+="    ** TESTING ONLY ***\n"
    msg+="Processing keyboard commands locally.\n";
    echo -e "$msg";
    echoServerCommandDocs
else
    usage 1 "ERROR: Expected \"INTERACTIVE\" or no arguments, encountered \"$1\""
fi

#===============================================================================
#===============================================================================

function shutdownServer() {
    # shutdownServer; Shut down the server.
    shutdownMsg="$1 Orderly Server Shutdown requested.  Bye!"
    if [ "$serverProcess" == "$foreground" ]; then
        # If we're not running in the background, display a message when shutting down
        echo -e "$shutdownMsg"
    fi
    if [ ! "$mode" == "$interactive" ]; then
        # If we're running the server "as a service" (i.e. listening on the pipes)
        # then send a shutdown message over to any open clients.
        # for clientPipe in "${pipes_dir}"/*
        # do
        #     if [ -p "$clientPipe" ] && [ "$clientPipe" != "$pipes_dir/server.pipe" ]; then
        #         echo "SERVER.SH: Found a client pipe. Informing it of shutdown: (${clientPipe})"
        #         echo -e "$shutdownMsg" > "$clientPipe"
        #     fi
        # done

        # The blocking bahviour of communcation over pipes was causing me issues
        # *IF* I was sticking to this design and *IF* this was a real application
        # I would create a background process for the client process just to 
        # monitor the client pipe and relay messages to the screen.
        if [ -p "$pipes_dir/$userId.pipe" ]; then
            echo -e "$shutdownMsg" > "$pipes_dir/$userId.pipe"
        fi
    fi
    tidyPipe "$1" "$2"
    exit 0
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
    shutdownServer "\nCTRL-C" "server.pipe"
    exit 1
}


#===============================================================================
#===============================================================================

# If we're not in INTERACTIVE mode, then before we enter our management loop,
# create our command pipe
if [ ! "$mode" == "$interactive" ]; then
    mkfifo "$pipes_dir/server.pipe"
fi

# For some notes on use of this seperator see Client.sh
delimSep=$'\x1F'

# Infinite server loop - only exits on command.
while true; do
    if [ "$mode" == "$interactive" ]; then
        echo ""
        read -p "Please enter a server command: " -r commandStr
        commandArr=()
        parseUserInstrnString "$commandStr" commandArr  # call function to parse the commandStr

        # -> In INTERACTIVE mode our commands will be the base commands
    else
        # In 'service' mode we read server commands from the server.pipe pipe
        #mapfile commandArr < server.pipe
        #read -r -a commandArr < server.pipe
        # Use xargs??
        #   https://superuser.com/questions/1529226/get-bash-to-respect-quotes-when-word-splitting-subshell-output
        #commandArr=("$commandStr")
        #read -r -a testArr <<< $commandStr
        old_ifs="$IFS"
        # Direct our string into read by treating it as a Here Word
        IFS=$delimSep read -r -a commandArr < "$pipes_dir/server.pipe"
        IFS="$old_ifs"  # Reset IFS so I haven't broken anything...
        # msg="SERVER.SH: Post pipe, our command array is:\n"
        # for arg in "${commandArr[@]}"; do
        #     msg+="\t>$arg<\n";
        # done
        # echo -e "$msg"

        # -> In 'Service' mode our commands will have a UserId first, followed by
        #    the base commands.  Grab out the user id...
        userId="${commandArr[0]}"
        #echo -e "SERVER.SH: userid is $userId"

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
    #echo -e "SERVER.SH: srvrCommand is $srvrCommand"
    argArr=("${commandArr[@]:1}")  # ... and then remove it from the array too...
    # msg="SERVER.SH: function arguments are:"
    # for fnArg in "${argArr[@]}"; do
    #     msg+=" >$fnArg<";
    # done
    # echo -e "$msg"

    case "$srvrCommand" in
    create_database)
        # create_database $database: creates database $database
        if [ "$mode" == "$interactive" ]; then
            "$home_dir/create_database.sh" "${argArr[@]}" >> "$home_dir/create_database.log" 2>&1 &
        else
            "$home_dir/create_database.sh" "${argArr[@]}" > "$pipes_dir/$userId.pipe" 2>&1 &
        fi
        ;;
    create_table)
        # create table $database $table: which creates table $table
        if [ "$mode" == "$interactive" ]; then
            "$home_dir/create_table.sh" "${argArr[@]}" >> "$home_dir/create_table.log" 2>&1 &
        else
            "$home_dir/create_table.sh" "${argArr[@]}" > "$pipes_dir/$userId.pipe" 2>&1 &
        fi
        ;;
    insert)
        # insert $database $table tuple: insert the tuple into table $table of database $database
        if [ "$mode" == "$interactive" ]; then
            "$home_dir/insert.sh" "${argArr[@]}" >> "$home_dir/insert.log" 2>&1 &
        else
            "$home_dir/insert.sh" "${argArr[@]}" > "$pipes_dir/$userId.pipe" 2>&1 &
        fi
        
        ;;
    select)
        # select $database $table tuple: display the columns from table $table of database $database
        if [ "$mode" == "$interactive" ]; then
            "$home_dir/select.sh" "${argArr[@]}" >> "$home_dir/select.log" 2>&1 &
        else
            "$home_dir/select.sh" "${argArr[@]}" > "$pipes_dir/$userId.pipe" 2>&1 &
        fi
        ;;
    server_shutdown)
        # shutdown: exit with a return code of 0
        if [ "$mode" == "$interactive" ]; then
            shutdownServer "SERVER.SH" "server.pipe"
        else
            shutdownServer "SERVER.SH" "server.pipe" > "$pipes_dir/$userId.pipe" 2>&1
        fi
        ;;
    *)
        errMsg="SERVER.SH: ERROR Bad command. I don't understand -> \"$srvrCommand\"";
        errMsg+="IGNORING.  Listening for more commands! ...";
        if [ "$mode" == "$interactive" ]; then
            echo -e "$errMsg"
        else
            echo -e "$errMsg" > "$pipes_dir/$userId.pipe"
        fi
    esac
done

# Parting note:  There is a ton of repetition in this script. It's littered with
# "if interactive, else..." logic.  I could have added a layer (file? another
# pipe?) and allowed the server to always write all content there.  Then at the
# end of a command choose where to sent the output.
#
# But I guess I don't have time for that so...