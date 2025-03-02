#!/usr/bin/env python
# Thomas Reerink
#
# This scripts needs two arguments:
#
# ${1} the first   argument is the cmip6plus cmor table    name
# ${2} the second  argument is the cmip6plus cmor variable name

# This script returns:
#  the cmip6 cmor table    name
#  the cmip6 cmor variable name
#  the status of conversion
#
# Run this script without arguments for examples how to call this script.
#

import sys                                                    # for sys.argv, sys.exit
import os.path                                                # for checking file existence with: os.path.isfile
import numpy as np                                            # for the use of e.g. np.multiply

error_message   = ' \033[91m' + 'Error:'   + '\033[0m'        # Red    error   message
warning_message = ' \033[93m' + 'Warning:' + '\033[0m'        # Yellow warning message

# Main program
def main():

    # FUNCTION DEFINITIONS:

    def load_cmip6_cmip6plus_map_table():
       # In case the path contains the ~ character this will be expanded to the home dir:
       file_name_mapping_table = 'cmip6-cmip6plus-mapping-table.txt'
       cmip6_cmip6plus_map_table_file_name = os.path.expanduser(file_name_mapping_table)

       # Checking if the cmip6-cmip6plus-mapping file exist, if not try to create it:
       if os.path.isfile(cmip6_cmip6plus_map_table_file_name) == False:

        # Git checkout of the github wiki table of the mip-cmor-tables if not available
        # for converting the github wiki table to an ascii file with columns:
        #  https://github.com/PCMDI/mip-cmor-tables/wiki/Mapping-between-variables-in-CMIP6-and-CMIP6Plus
        wiki_table_file = 'mip-cmor-tables.wiki/Mapping-between-variables-in-CMIP6-and-CMIP6Plus.md'
        if not os.path.isfile(wiki_table_file):
         command_1 = "git clone git@github.com:PCMDI/mip-cmor-tables.wiki"
         print(' Cloning git repo mip-cmor-tables.wiki:')
         print('  ' + command_1 + '\n')
         os.system(command_1)

        print('\n Creating the {} neat columnwise ascii file by applying:'.format(file_name_mapping_table))
        command_2 = "sed -e '/| CMIP6 table |/,$!d' -e 's/|/ /g' " + wiki_table_file + " | column -t > " + file_name_mapping_table
        print('  ' + command_2)
        os.system(command_2)
        command_3 = "sed -i -e 's/CMIP6.*/CMIP6 table  CMIP6 variable       CMIP6Plus Table CMIP6Plus  variable   Notes/' " + file_name_mapping_table
        print('  ' + command_3 + '\n')
        os.system(command_3)

        print(' Remove trailing spaces:')
        command_4 = "sed -i -e 's/ *$//g' " + file_name_mapping_table
        print('  ' + command_4 + '\n')
        os.system(command_4)

        print(' Improve readability of notes:')
        command_5 = "sed -i -e 's/Note       Variable  name       change/Note Variable name change/' " + file_name_mapping_table
        print('  ' + command_5)
        os.system(command_5)
        command_6 = "sed -i -e 's/Note       change    in         cell_methods/Note change incell_methods/' " + file_name_mapping_table
        print('  ' + command_6 + '\n')
        os.system(command_6)

       if os.path.isfile(cmip6_cmip6plus_map_table_file_name) == False: print(error_message, ' The file ', cmip6_cmip6plus_map_table_file_name, '  does not exist.\n'); sys.exit()

       # Loading the cmip6-cmip6plus-mapping file
       cmip6_cmip6plus_map_table = np.loadtxt(cmip6_cmip6plus_map_table_file_name, skiprows=2, usecols=(0,1,2,3), dtype='str')

       # Clean:
       command_7 = "rm -rf mip-cmor-tables.wiki"
       os.system(command_7)

       return cmip6_cmip6plus_map_table


    # MAIN:

    if len(sys.argv) == 3:

       verbose = False
       if verbose: print('\n Executing:  ', ' '.join(sys.argv[:]))  # Echo the command (allow debug tracing when called from an overarching script)

      #if __name__ == "__main__": config = {}                       # python config syntax

       cmip6plus_table    = sys.argv[1]
       cmip6plus_variable = sys.argv[2]
       if verbose:
        print("\n Looking up the CMIP6 equivalents of the CMIP6plus table {} and CMIP6plus variable {}\n".format(cmip6plus_table, cmip6plus_variable))

       # Load (and create if necessary) the cmip6 cmip6plus map table:
       cmip6_cmip6plus_map_table = load_cmip6_cmip6plus_map_table()

       cmip6_table    = None
       cmip6_variable = None
       for line in cmip6_cmip6plus_map_table:
        if line[2] == cmip6plus_table and line[3] == cmip6plus_variable:
         cmip6_table    = line[0]
         cmip6_variable = line[1]
         if verbose: print(' {}\n'.format(str(line)))
         exit

       if cmip6plus_table == None:
        status='nomatch'
       elif cmip6plus_table == cmip6_table and cmip6plus_variable == cmip6_variable:
        status='equal'
       else:
        status='converted'

       print("{} {} {}".format(cmip6_table, cmip6_variable, status))

    else:
     print()
     print(' This script needs two argument: table variable. E.g.:')
     print('  ', sys.argv[0], 'AP3hrPt tas')
     print('  ', sys.argv[0], 'APmon   hus19')
     print('  ', sys.argv[0], 'LImon   tsn')
     print()

if __name__ == "__main__":
    main()
