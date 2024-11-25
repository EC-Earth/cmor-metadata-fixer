#!/usr/bin/env bash
# Thomas Reerink
#
# Run this script without arguments for examples how to call this script.
#
# This scripts converts the github wiki table to an ascii file with columns:
#  https://github.com/PCMDI/mip-cmor-tables/wiki/Mapping-between-variables-in-CMIP6-and-CMIP6Plus
#

 if [ "$#" -eq 0 ]; then

  wiki_table_file=mip-cmor-tables.wiki/Mapping-between-variables-in-CMIP6-and-CMIP6Plus.md
  if [ ! -f ${wiki_table_file} ]; then
   git clone git@github.com:PCMDI/mip-cmor-tables.wiki
  fi

  # Remove the non table part and the table markdown syntax and align the columns neatly:
  sed -e '/| CMIP6 table |/,$!d' -e 's/|/ /g' ${wiki_table_file} | column -t > cmip6-cmip6plus-mapping.txt

 else
  echo
  echo " Illegal number of arguments. Needs no arguments:"
  echo "  $0"
  echo
 fi
