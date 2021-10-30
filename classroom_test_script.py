from subprocess import PIPE, Popen, list2cmdline
import os

def run_cmd(command, should_print=False):
    print("Running ", list2cmdline(command))
    with Popen(command, stdin=PIPE, stdout=PIPE, stderr=PIPE, shell=False) as process:
        (stdout, stderr) = process.communicate()
        if should_print:
            print("stderr:\n%s\nstdout:\n%s\n" % (stderr, stdout))
        return process.wait()

def check_if_string_in_file(file_name, string_to_search):
    """ Check if any line in the file contains given string """
    # Open the file in read only mode
    with open(file_name, 'r') as read_obj:
        # Read all lines in the file one by one
        for line in read_obj:
            # For each line, check if line contains the string
            if string_to_search in line:
                return True
    return False

print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
print("#TESTING: create_database.sh")

print(" ")
print("#Should fail, no parameters:")
if run_cmd(["./create_database.sh"]) == 0:
    print("#create_database.sh should have failed because no parameter")
    exit(1)

print(" ")
print("#Should fail, too many parameters:")
if run_cmd(["./create_database.sh", "testDB", "testDB1"]) == 0:
    print("#create_database.sh should have failed because too many parameter")
    exit(1)

print(" ")
print("#Should succeed:")
run_cmd(["./create_database.sh", "testDB"])

if os.path.isdir("./testDB"):
    print("#Created the folder ./testDB correctly")
else:
    print("#Did not create the testDB folder")
    exit(1)

print(" ")
print("#Should fail because db already exists:")
if run_cmd(["./create_database.sh", "testDB"]) == 0:
    print("#create_database.sh should have failed as the db already exists")
    exit(1)

print(" ")
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
print("#TESTING: create_table.sh")

print(" ")
print("#Should fail because too many parameters:")
if run_cmd(["./create_table.sh", "testDB", "testTable", "c1,c2,c3", "wrong"]) == 0:
    print("create_table.sh should have failed because too many parameters")
    exit(1)

print(" ")
print("#Should fail because too few parameters:")
if run_cmd(["./create_table.sh", "testDB", "testTable"]) == 0:
    print("create_table.sh should have failed because too few parameters")
    exit(1)

print(" ")
print("#Should fail because db does not exist:")
if run_cmd(["./create_table.sh", "testDB1", "testTable", "c1,c2,c3"]) == 0:
    print("#create_table.sh should have failed because db does not exist")
    exit(1)

print(" ")
print("#Should succeed:")
run_cmd(["./create_table.sh", "testDB", "testTable", "c1,c2,c3"])

if os.path.isfile("./testDB/testTable"):
    print("#Created the file './testTable' correctly")
else:
    print("#Did not create the file")
    exit(1)

if not check_if_string_in_file("./testDB/testTable", "c1,c2,c3"):
    print("#Columns header not added to testTable correctly")
    exit(1)

print(" ")
print("#Should fail because table already exists:")
if run_cmd(["./create_table.sh", "testDB", "testTable", "c1,c2,c3"]) == 0:
    print("#create_table.sh should have failed because testTable already exists")
    exit(1)

print(" ")
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
print("#TESTING: insert.sh")

print(" ")
print("#Should fail because too many params:")
if run_cmd(["./insert.sh", "testDB", "testTable", "v1,v2,v3", "wrong"]) == 0:
    print("#insert.sh should have failed because too many")
    exit(1)

print(" ")
print("#Should fail because too few params:")
if run_cmd(["./insert.sh", "testDB", "testTable"]) == 0:
    print("#insert.sh should have failed because too few params")
    exit(1)

print(" ")
print("#Should fail because db doesnt exist:")
if run_cmd(["./insert.sh", "testDB1", "testTable", "v1,v2,v3"]) == 0:
    print("#insert.sh should have failed because db doesnt exist")
    exit(1)

print(" ")
print("#Should fail because table doesnt exist:")
if run_cmd(["./insert.sh", "testDB", "testTable1", "v1,v2,v3"]) == 0:
    print("#insert.sh should have failed because table doesnt exist")
    exit(1)

print(" ")
print("#Should fail because wrong number of columns:")
if run_cmd(["./insert.sh", "testDB", "testTable", "v1,v2,v3,v4"]) == 0:
    print("#insert.sh should have failed because wrong number of columns provided")
    exit(1)

print(" ")
print("#Should succeed:")
run_cmd(["./insert.sh", "testDB", "testTable", "v1,v2,v3"])
if not check_if_string_in_file("./testDB/testTable", "v1,v2,v3"):
    print("#Did not add the row to the table")
    exit(1)

print(" ")
print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
print("#TESTING: select.sh")

print(" ")
print("#Should fail because too many params:")
if run_cmd(["./select.sh", "testDB", "testTable", "2", "wrong"]) == 0:
    print("#select.sh should have failed because too many params")
    exit(1)

print(" ")
print("#Should fail because too few params:")
if run_cmd(["./select.sh", "testDB"]) == 0:
    print("#select.sh should have failed because too few params")
    exit(1)

print(" ")
print("#Should fail because db doesnt exist:")
if run_cmd(["./select.sh", "testDB1", "testTable", "1,2"]) == 0:
    print("#select.sh should have failed because db doesnt exist")
    exit(1)

print(" ")
print("#Should fail because table doesn't exist:")
if run_cmd(["./select.sh", "testDB", "testTable1", "1,2"]) == 0:
    print("#select.sh should have failed because table doesn't exist")
    exit(1)

print(" ")
print("#Should fail because column doesn't exist:")
if run_cmd(["./select.sh", "testDB", "testTable", "4"]) == 0:
    print("select.sh should have failed because column doesn't exist")
    exit(1)

print(" ")
print("#Should fail because column doesn't exist:")
if run_cmd(["./select.sh", "testDB", "testTable", "0"]) == 0:
    print("select.sh should have failed because column doesn't exist")
    exit(1)

print(" ")
print("#Should succeed:")
run_cmd(["./select.sh", "testDB", "testTable", "1,2"])

print(" ")
print("Ta-da!")
