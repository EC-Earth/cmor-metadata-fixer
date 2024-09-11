#!/usr/bin/env bash
# Thomas Reerink
#
# Fix metadata in cmorised data for any CMIP model.
#
# This scripts requires one argument.
#

# CMORISEDDIR is the directory with the cmorised data
# METADATAFILE    is the name with the meta data correction, for instance: metadata-correction-cases/knmi-metadata-corrections-piControl.json


# Example running directly from the command line on the main node:
# ./cmorMDfixer.py --verbose --dry --forceid --olist --npp 1 /scratch/nktr/cmorised-results/cmorMDfixer-test-data/test-set-01/CMIP6


 if [ "$#" -eq 1 ]; then

  METADATAFILE=metadata-correction-cases/knmi-metadata-corrections-piControl.json
  CMORISEDDIR=cmorMDfixer-test-data/test-set-01/CMIP6
  test_file=${CMORISEDDIR}/CMIP/EC-Earth-Consortium/EC-Earth3/piControl/r1i1p1f1/Eyr/treeFrac/gr/v20240129/treeFrac_Eyr_EC-Earth3_piControl_r1i1p1f1_gr_1850-1850.nc

  choice=$1

  if [ "${choice}" = "clean" ]; then
   rm -f list-of-modified-files.txt
   git checkout ${CMORISEDDIR}/*/*/*/*/*/Eyr/*/*/*/*.nc
  elif [ "${choice}" = "dry" ] || [ "${choice}" = "modify" ]; then
   if [ ! "${CONDA_DEFAULT_ENV}" = "cmorMDfixer" ]; then
    echo
    echo ' The CMIP6 data request tool cmorMDfixer is not available because of one of the following reasons:'
    echo '  1. cmorMDfixer might be not installed'
    echo '  2. cmorMDfixer might be not active, check whether the cmorMDfixer environment is activated'
    echo ' Stop'
    echo
    exit
   fi

   echo
   echo " Show the three attribute values which are subject of the test BEFORE they are modified with the cmorMDfixer (with use of ncdump):"
   echo
   ncdump -h ${test_file} | grep -e branch_time_in_parent -e branch_time_in_child -e parent_experiment_id
   echo

   # Remove the list-of-modified-files.txt to avoid the warning during the test that another file name is tried:
   rm -f list-of-modified-files.txt

   verbose="--verbose"
   verbose=""
   if [ "${choice}" = "dry" ]; then
   ./cmorMDfixer.py ${verbose} --dry --forceid --olist --addattrs ${METADATAFILE} ${CMORISEDDIR}
    else
   ./cmorMDfixer.py ${verbose}       --forceid --olist --addattrs ${METADATAFILE} ${CMORISEDDIR}
   fi

   echo
   echo " Show the three attribute values which are subject of the test AFTER they are modified with the cmorMDfixer (with use of ncdump):"
   echo
   ncdump -h ${test_file} | grep -e branch_time_in_parent -e branch_time_in_child -e parent_experiment_id
   echo

   echo "The treated files are listed in list-of-modified-files.txt:"
   more list-of-modified-files.txt
   echo
  else
   echo " The argument has to be one of the following options:"
   echo "  dry     |  A test run is done with the dry-run mode"
   echo "  modify  |  A test run is done in which the modifications are actively applied"
   echo "  clean   |  No test run is done, the changes are reset in the test-data"
  fi

 else
  echo
  echo "  Illegal number of arguments: this script requires one argument, for instance:"
  echo "   $0 dry "
  echo "   $0 modify"
  echo "   $0 clean"
  echo
 fi