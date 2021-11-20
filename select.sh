#!/bin/bash
# select.sh; Select some data from a database table (file)

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
    errMsg="$2  \n\e[1mUsage\e[0m:\n"
    errMsg+="\e[3m$0 database_name table_name [ columns ]\e[0m\n"
    errMsg+="\e[1m-OR-\e[0m\n"
    errMsg+="\e[3m$0 database_name table_name [ columns ]\e[0m\n"
    errMsg+="            \e[3m[ WHERE where_comparison_column where_comparison_value ]\e[0m\n"
    echo -e "$errMsg"
    exit "$1"  # exit with error status
}
# I'm taking a variable number of arguments for this script, so I need to be a
# little careful when I'm parsing them.  The argument checking is not perfect,
# I'm hoping it's sufficient for this exercise.
if [ -z "$1" ]; then
    usage 1 "ERROR You must supply a database name.";
elif [ -z "$2" ]; then
    usage 1 "ERROR You must supply a table name.";
fi

database=$1
table=$2
# We know we have the database and table now so get rid of them.
shift 2
# Initialise some values, makes me happier having things defined... :-)
colArr=""; where=""; whereCol=""; whereVal="";
# The next argument is either the (optional) columns to select.  Or it's my
# WHERE clause...
if [ -n "$1" ] && [ "$1" != "WHERE" ]; then
    # I want to turn the supplied tuple into a nice, handy array.
    # The special shell var 'IFS' determines how Bash recognizes word boundaries
    # while splitting a seq. of character strings (default: space, tab, newline)
    # I'm going to temporarily change it to "," (my delimiter)
    old_ifs="$IFS"
    # Using "read -a" assigns the words read to sequential indices of my array
    # (technically I don't need -r here, but using it does no harm and suppresses
    # a warning in my IDE)
    # Direct our string into read by treating it as a Here Word
    IFS=',' read -r -a colArr <<< "$1"
    IFS="$old_ifs"  # Reset IFS so I haven't broken anything...

    # colArr could potentially contain anything now, check it...
    regex="^[0-9]+$"
    for col in "${colArr[@]}"; do
        if ! [[ $col =~ $regex ]] ; then
            usage 1 "ERROR Only positive numeric column positions are considered: '$1'.";
        fi
    done

    shift  # Whatever the value... we 'consume' it...
fi
# There may be no args left. Or we may be parsing a WHERE clause
# If $1 has a value, it can 
if [ -n "$1" ]; then
    if  [ "$1" == "WHERE" ]; then
        where="$1";
    else
        usage 1 "ERROR Expected keyword 'WHERE', encountered '$1'.";
    fi
    if [ -z "$2" ]; then
        usage 1 "ERROR You must supply a column for the WHERE clause.";
    elif [ -z "$3" ]; then
        usage 1 "ERROR You must supply a value for the WHERE clause.";
    fi
    whereCol=$2; whereVal=$3
fi

# Sanity check (can't tell how many times I've used this!)
#echo $database, $table, ">$colArr<", $where, $whereCol , $whereVal

# If the database exists (we don't care if it's a regular file, or a directory,
# or whatever) - then this is an error and we abort
if [ ! -d "$data_dir/$database" ]; then
    echo -e "ERROR The database \e[1m$database\e[0m does not exist!  Aborting..." >&2 # &2 is standard error output
    exit 2 # the exit code that shows the db does not exist
elif [ ! -e "$data_dir/$database/$table" ]; then
    echo -e "ERROR The table \e[1m$table\e[0m does not exist!  Aborting..." >&2 # &2 is standard error output
    exit 3 # the exit code that shows the table does not exist
fi

# We establish how many columns are in our table header.
noDelimsInTableHeader=$(head -n 1 "$data_dir/$database/$table" | grep -o ","  | wc -l)
noColsInTable=$(( noDelimsInTableHeader + 1))

# We know how many columns are in the table.  We know our colArr contains
# a space seperated list of cols to select.  We want to Loop over the colArr
# now to check each column selected.
for col in "${colArr[@]}"; do
    if (( col < 1 )) || (( col > noColsInTable )); then
        err_msg="ERROR The table \e[1m$table\e[0m has $noColsInTable columns.\n"
        err_msg+="You have requested data from column $col?\n"
        err_msg+="Selected column out of bounds! Aborting..."
        usage 1 "$err_msg";
    fi
done

# OK - we've done a fair bit of checking to make sure our arguments make sense
# Now time to display the data.
sql_results="start_result\n"

# First we loop over the table file, one record at a time...
firstRecord=true  # We always select the first record.  Even if no data records
                  # are selected, we want to output the column headings.

# Lock the table *** for the entire duration of the read ***!!!
# This is the only way to ensure we don't get half a write
# TODO: Confirm approach with the TA in lab
getLock_P "$data_dir/$database/$table"
while read -r record; do
    # Convert the record just read into another, nice, handy array...
    old_ifs="$IFS"
    IFS=',' read -r -a recordArr <<< "$record"
    IFS="$old_ifs"  # Reset IFS so I haven't broken anything...

    # Now we have a record in hand (ok - as an array of columns), we want to
    # only selected the columns requested, by numeric position.
    retrievedData=""
    select=false

    addComma=false
    # It's probably terribly inefficient, but I loop through all the columns
    # the check if any WHERE clause matches.  Then later I'll loop through the
    # columns again to populate the output.  I did this in case the column
    # specified in the WHERE clause was not included in the output set.
    if [ "$firstRecord" = true ]; then
        select=true
        firstRecord=false
    elif [ "$where" == "WHERE" ]; then
        for idx in "${!recordArr[@]}"; do
            # The array index are numbered from 0 to len-1
            # The cols are numbered from 1 to len
            # So add 1 to idx before comparing to whereCol
            if (( (idx + 1) == whereCol )) && [ "${recordArr[(($idx))]}" == "$whereVal" ]; then
                select=true
            fi
        done
    else
        select=true
    fi

    if [ "$select" = true ]; then
        for col in "${colArr[@]}"; do
            # We build our retrieved data whether 'select' is true or not.  Select
            # may only become true when we hit the last field.  So we populated
            # the retrievedData string based on selected 
            if [ "$addComma" = true ]; then
                retrievedData+=","
            else
                addComma=true
            fi
            retrievedData+="${recordArr[(($col-1))]}"
        done
        sql_results+="$retrievedData\n"
    fi

done < "$data_dir/$database/$table"
# Release the lock on the table after the read is complete
releaseLock_V "$data_dir/$database/$table"

sql_results+="end_result"
echo -e "$sql_results"