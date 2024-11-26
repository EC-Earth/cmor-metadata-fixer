#!/usr/bin/env python
# Thomas Reerink
#
# This scripts needs two arguments:
#
# ${1} the first   argument is the cmip6 cmor table    name
# ${2} the second  argument is the cmip6 cmor variable name

# This script returns:
#  the cmip6plus cmor table    name
#  the cmip6plus cmor variable name
#
# Run this script without arguments for examples how to call this script.
#

import sys                                                    # for sys.argv, sys.exit
import os.path                                                # for checking file existence with: os.path.isfile
import numpy as np                                            # for the use of e.g. np.multiply
import math                                                   # for math.trunc
import subprocess                                             # For issuing commands to the OS.

error_message   = '\n \033[91m' + 'Error:'   + '\033[0m'      # Red    error   message
warning_message = '\n \033[93m' + 'Warning:' + '\033[0m'      # Yellow warning message


#def lookup_cmip6plus_equivalent_of_cmip6

if len(sys.argv) == 3:

   # In case the path contains the ~ character this will be expanded to the home dir:
   cmip6_cmip6plus_map_table_file_name = os.path.expanduser('cmip6-cmip6plus-mapping.txt')

   verbose = False
   if verbose:
    print('\n Executing:  ', ' '.join(sys.argv[:]))           # Echo the command (allow debug tracing when called from an overarching script)

   if __name__ == "__main__": config = {}                     # python config syntax

   cmip6_table    = sys.argv[1]
   cmip6_variable = sys.argv[2]
   if verbose:
    print("\n Looking up the CMIP6plus equivalents of the CMIP6 table {} and CMIP6 variable {}\n".format(cmip6_table, cmip6_variable))

   # Checking if the file exist:
   if os.path.isfile(cmip6_cmip6plus_map_table_file_name) == False:
    command='./convert-cmip6-cmip6plus-mapping-wiki-to-neat-columns.sh'
    os.system(command)
   if os.path.isfile(cmip6_cmip6plus_map_table_file_name) == False: print(error_message, ' The file ', cmip6_cmip6plus_map_table_file_name, '  does not exist.\n'); sys.exit()

   cmip6_cmip6plus_map_table = np.loadtxt(cmip6_cmip6plus_map_table_file_name, skiprows=2, usecols=(0,1,2,3), dtype='str')

   cmip6plus_table    = None
   cmip6plus_variable = None
   for line in cmip6_cmip6plus_map_table:
    if line[0] == cmip6_table and line[1] == cmip6_variable:
     cmip6plus_table    = line[2]
     cmip6plus_variable = line[3]
     if verbose:
      print(line)
     exit

   if cmip6plus_table == None:
    status='nomatch'
   elif cmip6plus_table == cmip6_table and cmip6plus_variable == cmip6_variable:
    status='equal'
   else:
    status='converted'

   print("{} {} {}".format(cmip6plus_table, cmip6plus_variable, status))

else:
   print()
   print(' This script needs two argument: table variable. E.g.:')
   print('  ', sys.argv[0], '3hr   tas')
   print('  ', sys.argv[0], 'Amon  hus')
   print('  ', sys.argv[0], 'LImon tsn')
   print()
