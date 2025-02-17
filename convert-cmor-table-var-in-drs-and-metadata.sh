#!/usr/bin/env bash
# Thomas Reerink
#
# Run this script without arguments for examples how to call this script.
#
# This scripts converts CMIP6 data to CMIP6Plus including the DRS adjustment.
#

 if [ "$#" -eq 1 ]; then

  export duplicate_data=True
  export verbose=False
  export data_dir=$1
  export log_file=${0/.sh/.log}


  function convert_cmip6_to_cmip6plus() {
   local i=$1

   # Sanity check on the `CMIP6` anchor point in the CMOR DRS:
   check_cmip6=`echo ${i} | cut -d/ -f3`
   if [ "${check_cmip6}" = "CMIP6" ]; then
    # Obtain the table and var name from the file path and name:
    table=`echo ${i} | cut -d/ -f9`
    var=`echo ${i} | cut -d/ -f10`

    # Find the equivalent table and variable name and the convert status and catch the script output in an array:
    converted_result=(`./map-cmip6-to-cmip6plus.py ${table} ${var}`)
    # Put the three returned values into three separate variables:
    converted_table=${converted_result[0]}
    converted_var=${converted_result[1]}
    status=${converted_result[2]}

    if [ ${verbose} = True ] ; then
     echo
     echo " Lookup CMIP6Plus equivalent of the CMIP6 ${table} ${var}:"
     echo "  ${status}"
     echo "  ${converted_table}"
     echo "  ${converted_var}"
     echo
    fi

    if [ "${status}" = "converted" ]; then
     imod=`echo ${i} | sed -e "s/${table}/${converted_table}/g" -e "s/${var}/${converted_var}/g" -e "s/CMIP6/CMIP6Plus/g"`
     mkdir -p ${imod%/*}
     if [ ${duplicate_data} = True ] ; then
      # Duplicate data to CMIP6plus DRS based directory for conversion to CMIP6plus:
      rsync -a ${i} ${imod}
     else
      # Move data to CMIP6plus DRS based directory for conversion to CMIP6plus:
      mv -f ${i} ${imod}
     fi
     if [ ${var} != ${converted_var} ]; then
      ncrename -O -v ${var},${converted_var} ${imod}
     fi

     # Get the actual model configuration:
     source_id=`ncdump -h ${i} | grep '.*:source_id = "' | sed -e 's/.*:source_id = "//' -e 's/" ;//'`
     # Set the CMIP6Plus license:
     license="CMIP6Plus model data produced by EC-Earth-Consortium is licensed under a Creative Commons 4.0 (CC BY 4.0) License (https://creativecommons.org/). Consult https://pcmdi.llnl.gov/CMIP6Plus/TermsOfUse for terms of use governing CMIP6Plus output, including citation requirements and proper acknowledgment. The data producers and data providers make no warranty, either express or implied, including, but not limited to, warranties of merchantability and fitness for a particular purpose. All liabilities arising from the supply of the information (including any liability arising in negligence) are excluded to the fullest extent permitted by law."
     institution="EC-Earth-Consortium - EC-Earth-Consortium [consortium]"
     authors="XXXX"
     comment="This experiment was done as part of OptimESM (https://optimesm-he.eu/) by "${authors}
     description="CMIP6Plus "
     history_addition="\nThe cmorMDfixer CMIP6 => CMIP6Plus convertscript has been applied.;\n"

     # Modification of these global attributes could be done as well with cmorMDfixer (though for table_id is easier here:
     ncatted -O -h -a table_id,global,m,c,${converted_table}                        ${imod}
     ncatted -O -h -a mip_era,global,m,c,"CMIP6Plus"                                ${imod}
     ncatted -O -h -a parent_mip_era,global,m,c,"CMIP6Plus"                         ${imod}
     ncatted -O -h -a title,global,m,c,${source_id}" output prepared for CMIP6Plus" ${imod}
     ncatted -O -h -a license,global,m,c,"${license}"                               ${imod}
     ncatted -O -h -a further_info_url,global,d,,                                   ${imod}
     ncatted -O -h -a institution,global,m,c,"${institution}"                       ${imod}
     ncatted -O -h -a comment,global,c,c,"${comment}"                               ${imod}
     ncatted -O -h -a description,global,c,c,"${description}"                       ${imod}
     ncatted -O -h -a history,global,a,c,"${history_addition}"                      ${imod} # some rubisch \000\000... string is added

    echo "${imod}" >> ${log_file}

    else
     echo " No action conversion has been taken, the convert status is: ${status}"
    fi
   else
    echo " Abort $0 because the root dir CMIP6 is not at the expected location in the path, instead we found: ${check_cmip6} at the expected location."
   fi
  }

  export -f  convert_cmip6_to_cmip6plus

  > ${log_file}

  # Check whether gnu parallel is available:
  if hash parallel 2>/dev/null; then
   echo; echo " Run $0 in parallel mode."; echo
   find ${data_dir} -name '*.nc' | parallel -I% convert_cmip6_to_cmip6plus %
  else
    echo; echo " Run $0 in sequential mode."; echo
   for i in `find ${data_dir} -name '*.nc'`; do
    convert_cmip6_to_cmip6plus $i
   done
  fi

  # Guarantee same order:
  sort ${log_file} > ${log_file/.log/-sorted.log}

 else
  echo
  echo " Illegal number of arguments. Needs one argument, the data dir with your cmorised CMIP6 data:"
  echo "  $0 cmorMDfixer-test-data/test-set-01/CMIP6/"
  echo
 fi


# Compare and evaluate this script with:
# ./convert-cmor-table-var-in-drs-and-metadata.sh new-data/hpc2020/CMIP6/; ncdump -h new-data/hpc2020/CMIP6Plus/CMIP/EC-Earth-Consortium/EC-Earth3-ESM-1/esm-hist/r1i1p1f1/OPmon/tos/gn/v20250217/tos_OPmon_EC-Earth3-ESM-1_esm-hist_r1i1p1f1_gn_199001-199012.nc > tos_OPmon_EC-Earth3-ESM-1_esm-hist_r1i1p1f1_gn-cmip6Plus-converted.txt; sort tos_OPmon_EC-Earth3-ESM-1_esm-hist_r1i1p1f1_gn-cmip6Plus-converted.txt > tos_OPmon_EC-Earth3-ESM-1_esm-hist_r1i1p1f1_gn-cmip6Plus-converted-sorted.txt

# cmorised CMIP6Plus                              converted CMIP6Plus
# title = "EC-Earth3-ESM-1 output prepared for"   title = "EC-Earth3-ESM-1 output prepared for CMIP6Plus"   # Thus missing the CMIP6Plus at the end of the string.
# data_specs_version = "6.5.0.0" ;        vs      :data_specs_version = "01.00.33" ;
# "seaIce: LIM3 (same grid as ocean))" ;

# Simple parallel - bash function example:
#function message() { echo $1 ; }; export -f message; find cmorMDfixer-test-data/test-set-01 -type f | parallel -I% message %
