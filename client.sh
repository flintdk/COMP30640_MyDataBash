#!/bin/bash
# client.sh; Reads commands from clients and executes them

# Set up home directory and include shared resources
home_dir="$(pwd)"
# shellcheck source=./dbutils.sh
source "$home_dir/dbutils.sh"

# Helper function - save me keying command summary twice, ensures consistancy in
# user docs (such as they are)
function echoCommandDocs() {
    cmdMsg="Client Commands Processed:\n"
    cmdMsg+="  \e[3mhelp\e[0m - See this help text\n"
    cmdMsg+="  \e[3mcreate_database \"database_name\"\e[0m\n"
    cmdMsg+="  \e[3mcreate_table \"database_name\" \"table_name\" \"column,names,separated,by,commas\"\e[0m\n"
    cmdMsg+="  \e[3minsert \"database_name\" \"table_name\" \"data_tuple\"\e[0m\n"
    cmdMsg+="  \e[3mselect \"database_name\" \"table_name\" [ column,numbers,separated,by,commas ]\e[0m\n"
    cmdMsg+="            \e[3m[ WHERE comparison_column_number \"comparison_value\" ]\e[0m\n"
    cmdMsg+="  \e[3mlaunch\e[0m - Launch the remote server (in the background)\n"
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
    #echoCommandDocs  # Not sure whether to include this here........
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

# We clear the terminal, removes any clutter, hopefully helps the user
clear
echoCommandDocs

# Before we enter our management loop, create our command pipe
userId="$1"  # This does nothing, but does make code below easier to read.
if [ ! -e "$userId.pipe" ]; then
    mkfifo "$userId.pipe"
else
    echo "ERROR: Client Pipe (\"$userId.pipe\") already exists! Aborting..."
    exit 1
fi

# I store an array of valid commands, to allow for some quick, simple validation
# before sending any content to the server.
valid_commands=("create_database" "create_table" "insert" "select" "launch" "shutdown" "help" "exit")

# When your run a script from the command line, the script benefits from the
# rather nice word-splitting behaviour of the shell (where it splits on spaces
# but ignores quoted whitespaces).
# HOWEVER... when reading from sys$input (in Client.sh) or the pipe (in Server.sh)
# I (really) struggled with word-spliiting for any data that contained spaces.
#
# For the communication to the server over the server pipe I decided to delimit
# the commands I send to the server using a control-code (character).
# See: https://www.asciihex.com/ascii-control-characters
# There were a set of ASCII contol codes designed for just this purpose:
#   028  0001 1100  34  1C  FS - File Separator.
#   029  0001 1101  35  1D  GS - Group Separator.
#   030  0001 1110  36  1E  RS - Record Separator.
#   031  0001 1111  37  1F  US - Unit Separator.
# I chose to use the "Unit Separator" ('\031' -or- '\x1F') to delimit my commands
# The benefit of using a control code (instead of say ';' etc.) is that it's far
# less likely to occur in user-entered data.
delimSep=$'\x1F'

# Infinite client loop - only exits on command.
while true; do
    # NOTE Word splitting! Arghhh...
    # If you read in the user input as an array you get word splitting even if the input is well quoted.
    echo ""
    read -p "Please enter a command to send to the server ('help' for more): " -r commandStr
    #echo -e "CLIENT.SH Just after read from sysSinput. CommandStr received : $commandStr"

    commandArr=()
    parseUserInstrnString "$commandStr" commandArr  # call function to parse the commandStr
    # msg="CLIENT.SH Post Parsing. Arguments received are:\n"
    # for arg in "${commandArr[@]}"; do
    #     msg+="\t>$arg<\n";
    # done
    # echo -en "$msg"

    # We now have an array consisting of the users commands.
    clientCommand="${commandArr[0]}"
    # Remove the first element from the array now it's consumed.
    argArr=("${commandArr[@]:1}")  # we'll be passing all remaining arguments to the server

    # Check if the user issued command is a valid command.
    # NOTE: If my commands contained spaces the below would fail.  They don't.
    if [[ ${valid_commands[*]} =~ ${clientCommand} ]]; then
        # Per the specification, if the request is well formed, then we print out:
        #   -> req $id args
        # ...with $id being the id given as parameter of the client.sh script.
        # (use brace expansion to list out the remaining arguments)
        echo "$clientCommand $userId" "${argArr[@]}"

        # Some of the commands recieved are local 'client' commands (like help,
        # exit, etc.).  Others must be sent to the server.  Filter them here...
        case "$clientCommand" in  # CASE_ClientOrServer?
        help)
            # help: print a list of supported commands
            echo ""
            echoCommandDocs
            ;;
        launch)
            # help: print a list of supported commands
            echo "Launching Server.  Please wait..."
            "$home_dir/server.sh" > /dev/null 2>&1 &
            echo "Server Started.  Listening for more commands! ..."
            ;;
        exit)
            # shutdown: exit with a return code of 0
            shutdownClient "CLIENT.SH" "$userId.pipe"
            ;;
        *)
            # All other commands get relayed to the server

            # Do a basic 'server exists' check by looking for the server pipe
            # before relaying commands to it...
            if [ -p "$home_dir/server.pipe" ]; then
                serverCommand="${userId}${delimSep}${clientCommand}"
                for arg in "${argArr[@]}"; do
                    serverCommand+="${delimSep}$arg";
                done
                #echo -e "CLIENT.SH: Server Command (pre pipe): $serverCommand"
                echo "$serverCommand" > "server.pipe"

                # We've now sent our command to the server.  It's ESSENTIAL that we read
                # the reply pipe.  In bash, pipes are blocking.  So if the server writes a
                # reply to this clients result pipe, the server will be blocked indefinitely
                # until something on this end consumes the pipe contents!!
                case "$clientCommand" in  # CASE_ReplyProcessing
                select)
                    # With select, what has to be printed on the terminal is everything
                    # after the first word ('start result') until the keyword 'end result'
                    # For sed:
                    # 1 = first line, d = delete, ; is the cmd separator, $ = last line
                    sed '1d;$d' "$home_dir/$userId.pipe"
                    ;;
                *)
                    # For all other commands we simply cat out all the pipe content
                    # unfiltered...
                    cat "$home_dir/$userId.pipe"
                    ;;
                esac  # CASE_ReplyProcessing
            else
                errMsg="CLIENT.SH: ERROR It appears the server is not running!\n";
                errMsg+="           (No 'server.pipe' found).\n";
                errMsg+="Listening for more commands! ...";
                echo -e "$errMsg"
            fi
        esac  # CASE_ClientOrServer?

    else  # if [[ ${valid_commands[*]} =~ ${clientCommand} ]]; then
        errMsg="CLIENT.SH: ERROR Bad command. I don't understand -> \"$clientCommand\"\n";
        errMsg+="Listening for more commands! ...";
        echo -e "$errMsg"
    fi
done