#!/bin/bash
# server.sh; Reads commands from clients and executes them

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
    errMsg="\e[3m$0\e[0m \e[3m[create_database | create_table | insert | select | shutdown]\e[0m\n"
    errMsg+="  \e[3mcreate_database\e[0m \e[3mdatabase_name\e[0m\n"
    errMsg+="  \e[3mcreate_table\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3mcolumns_name\e[0m\n"
    errMsg+="  \e[3minsert\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3mdata_tuple\e[0m\n"
    errMsg+="  \e[3mselect\e[0m \e[3mdatabase_name\e[0m \e[3mtable_name\e[0m \e[3mcolumns\e[0m\n"
    errMsg+="            \e[3mWHERE\e[0m \e[3mwhere_comparison_column\e[0m \e[3mwhere_comparison_value\e[0m\n"
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

# Infinite server loop - only exits on command.
while true; do
    if [ "$mode" == "$interactive" ]; then
        echo -n "Please enter a server command: ";
        #read -r command;
        old_ifs="$IFS"
        IFS=' ' read -r -a commandArr
        IFS="$old_ifs"  # Reset IFS so I haven't broken anything...
    else
        echo "SERVER.SH Service mode not supported yet - watch yer syntax!!"
        exit 1
    fi

    # We now have an array consisting of the users commands.
    srvrCommand="${commandArr[0]}"
    # Use a new method (to me) to remove the first element from the array. See:
    #   https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
    # See the section starting with 'If parameter is an indexed array name
    # subscripted by ‘@’ or ‘*’, the result...'
    # This neat little syntax lets me extract whatever array elements I want!
    #unset commandArr[0]
    commandArr=("${commandArr[@]:1}")  # we'll be passing all remaining arguments to the command scripts
    # msg="function arguments are:"
    # for fnArg in "${commandArr[@]}"; do
    #     msg+=" $fnArg";
    # done
    # echo "$msg"

    case "$srvrCommand" in
    create_database)
        # create_database $database: creates database $database
        ./create_database.sh "${commandArr[@]}"
        ;;
    create_table)
        # create table $database $table: which creates table $table
        ./create_table.sh "${commandArr[@]}"
        ;;
    insert)
        # insert $database $table tuple: insert the tuple into table $table of database $database
        ./insert.sh "${commandArr[@]}"
        ;;
    select)
        # select $database $table tuple: display the columns from table $table of database $database
        ./select.sh "${commandArr[@]}"
        ;;
    shutdown)
        # shutdown: exit with a return code of 0
        echo "SERVER.SH Orderly Shutdown requested.  Bye!"
        exit 0
        ;;
    *)
        errMsg="ERROR: Bad server command. I don't understand -> \"$1\"";
        errMsg+="Ignoring, logging and listening for more commands!";
        echo "$errMsg"
    esac
done