#!/usr/bin/env bash
# Thomas Reerink
#
# This script is a wrapper of cmorMDfixer. It only applies cmorMDfixer changes when in the dataset at least one error is found.
# That means, if all files in the entire dataset are correct, then no tracking_id will be changed anywhere.
#
# This scripts needs two arguments:
#
# ${1} the first   argument is the number of cores (one node can be used).
# ${2} the second  argument is path + filename of the metadata json file.
# ${2} the third   argument is path of the directory with the cmorised data.
#
# Run this script without arguments for examples how to call this script.
#

if [ "$#" -eq 3 ]; then

   number_of_cores=$1
   metadata_file=$2
   dir_with_cmorised_data=$3

   olist_1_filename='list-of-modified-files-1.txt'
   olist_2_filename='list-of-modified-files-2.txt'
   olist_3_filename='list-of-modified-files-3.txt'
   diff_olists='interruption-differences-list.txt'

   log_1_filename='cmorMDfixer-messages-1.log'
   log_2_filename='cmorMDfixer-messages-2.log'
   log_3_filename='cmorMDfixer-messages-3.log'

   if [[ -e ${olist_1_filename} || -e ${olist_2_filename} || -e ${olist_3_filename} || -e ${diff_olists} ]] ; then
    echo
    echo ' Aborting' $0 ' because you have to rename any of the files with the names:'
    echo ' ' ${olist_1_filename}
    echo ' ' ${olist_2_filename}
    echo ' ' ${olist_3_filename}
    echo ' ' ${diff_olists}
    echo
    exit 1
   fi

   if [ "${number_of_cores}" -lt 1 ] || [ "$1" -gt 128 ]; then
    echo -e "\e[1;31m Error:\e[0m"' The value of number of cores ' ${number_of_cores} ' is out of range. Allowed range: 1-128.' >&2
    exit 1
   fi

   if [ ! -f ${metadata_file} ]; then
    echo
    echo -e "\e[1;31m Error:\e[0m"' the metadata file ' ${metadata_file} ' does not exist.'
    echo
    exit 1
   fi

   if [ ! -d ${dir_with_cmorised_data} ]; then
    echo
    echo -e "\e[1;31m Error:\e[0m"' the directory ' ${dir_with_cmorised_data} ' does not exist.'
    echo
    exit 1
   fi


   echo 'Step 1: Before really applying the changes, create the olist for the --forceid case.' > ${log_1_filename}
   echo >> ${log_1_filename}
   ./cmorMDfixer.py --dry --verbose --forceid --olist --npp ${number_of_cores} ${metadata_file} ${dir_with_cmorised_data} &>> ${log_1_filename}

   if [[ ! -e ${olist_1_filename} ]] ; then
    echo
    echo -e "\e[1;31m Error:\e[0m"' the file ' ${olist_1_filename} ' should have been produced.'
    echo
    exit 1
   fi

   echo 'Step 2: Apply the changes for the files listed in the olist for the --forceid case.' > ${log_2_filename}
   echo >> ${log_2_filename}
   ./cmorMDfixer.py --verbose --forceid --olist --npp ${number_of_cores} ${metadata_file} ${dir_with_cmorised_data} &>> ${log_2_filename}

   if [[ ! -e ${olist_2_filename} ]] ; then
    echo
    echo -e "\e[1;31m Error:\e[0m"' the file ' ${olist_2_filename} ' should have been produced.'
    echo
    exit 1
   fi


   diff ${olist_2_filename} ${olist_1_filename} > ${diff_olists}

   if [[ ! -s ${diff_olists} ]]; then
    echo
    echo ' The changes are applied and agree with the preceding dry-run, so all seems fine (no interruption damage).'
    echo
    rm -f ${diff_olists}
   else
    echo
    echo -e "\e[1;33m Warning:\e[0m"' the ' ${diff_olists} ' file is not empty. So it seems that the dry-run before and the modification run thereafter differ.\e[1;33m Check for any interruption.\e[0m'
    echo
   fi


   echo 'Step 3: Check whether there are still modifications detected which should have been applied already (possibly as a consequence of an earlier interruption).' > ${log_3_filename}
   echo >> ${log_3_filename}
   ./cmorMDfixer.py --dry --verbose --olist --npp ${number_of_cores} ${metadata_file} ${dir_with_cmorised_data} &>> ${log_3_filename}

   if [[ ! -e ${olist_3_filename} ]] ; then
    echo
    echo -e "\e[1;31m Error:\e[0m"' the file ' ${olist_3_filename} ' should have been produced (in the post checking phase).'
    echo
    exit 1
   fi

   if [[ ! -s ${olist_3_filename} ]]; then
    echo
    echo ' All files in the entire dataset are correct after correcting, so ending successful!'
    echo
   else
    echo
    echo -e "\e[1;33m Warning:\e[0m"' After correcting with cmorMDfixer, it seems there are still errors in the dataset Check the files by looking into ' ${olist_3_filename}
    echo
   fi

   echo
   echo ' The versions.sh script detects the following versions in the final corrected dataset:'
   ./versions.sh -l ${dir_with_cmorised_data}
  #echo ' In order to set one new version (recommended), for instance to October 20 2024, the versions.sh script can be run now by:'
  #echo ' ./versions.sh -v v20241020 -m CMIP6/'
   echo


else
    echo
    echo "  This scripts requires two arguments:"
    echo "   The first  argument: is the number of cores (one node can be used)."
    echo "   The second argument: is the path + filename of the metadata json file."
    echo "   The third  argument: is the path of the directory which contains the cmorised data."
    echo "  For instance:"
    echo "   $0 1 metadata-file.json CMIP6/"
    echo "   $0 1 metadata-correction-cases/knmi-metadata-corrections-piControl.json cmorMDfixer-test-data/test-set-01/CMIP6"
    echo
fi
