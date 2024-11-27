#!/usr/bin/env bash
# Thomas Reerink
#
# Run this script without arguments for examples how to call this script.
#
# This scripts converts 
#

 if [ "$#" -eq 0 ]; then

  verbose=True
  verbose=False

  echo "" > ${0/.sh/.log}
  for i in `find cmorMDfixer-test-data/test-set-01/CMIP6/ -name '*.nc'`; do
   # Sanity check on the `CMIP6` anchor point in the CMOR DRS:
   check_cmip6=`echo ${i} | cut -d/ -f3`
   if [ "${check_cmip6}" = "CMIP6" ]; then
    # Obtain the table an var name from the file path and name:
    table=`echo ${i} | cut -d/ -f9`
    var=`echo ${i} | cut -d/ -f10`

    # Find the equivalent table and variable name and the convert status and catch the script output in an array:
    cd cmip6-cmip6plus-mapping/
    converted_restult=(`./map-cmip6-to-cmip6plus.py ${table} ${var}`)
    cd ../

    status=${converted_restult[2]}
    converted_table=${converted_restult[0]}
    converted_var=${converted_restult[1]}
    if [ ${verbose} = True ] ; then
     echo
     echo " Lookup CMIP6plus equivalent of the CMIP6 ${table} ${var}:"
     echo "  ${status}"
     echo "  ${converted_table}"
     echo "  ${converted_var}"
     echo
    fi

    if [ "${status}" = "converted" ]; then
     imod=`echo ${i} | sed -e "s/${table}/${converted_table}/g" -e "s/${var}/${converted_var}/g" -e "s/CMIP6/CMIP6plus/g"`
     mkdir -p ${imod%/*}
     rsync -a ${i} ${imod}
    #ncrename -O -v ${table},${converted_table} ${imod}
     if [ ${var} != ${converted_var} ]; then
      ncrename -O -v ${var},${converted_var} ${imod}
     fi
     # Modification of these global attributes could be done as well with cmorMDfixer (though for table_id is easier here:
     ncatted -O -h -a table_id,global,m,c,${converted_table}                     ${imod}
     ncatted -O -h -a mip_era,global,m,c,"CMIP6plus"                             ${imod}
     ncatted -O -h -a parent_mip_era,global,m,c,"CMIP6plus"                      ${imod}
     ncatted -O -h -a title,global,m,c,"EC-Earth3 output prepared for CMIP6plus" ${imod}
    #further_info_url = "https://furtherinfo.es-doc.org/CMIP6.EC-Earth-Consortium.EC-Earth3.piControl.none.r1i1p1f1" ;
    #history = "2024-01-29T12:58:34Z ; CMOR rewrote data to be consistent with CMIP6, CF-1.7 CMIP-6.2 and CF standards.;\n",
    #license = "CMIP6 model data produced by EC-Earth-Consortium is licensed under a Creative Commons Attribution 4.0 International License (https://creativecommons.org/licenses). Consult https://pcmdi.llnl.gov/CMIP6/TermsOfUse for terms of use governing CMIP6 output, including citation requirements and proper acknowledgment. Further information about this data, including some limitations, can be found via the further_info_url (recorded as a global attribute in this file) and at http://www.ec-earth.org. The data producers and data providers make no warranty, either express or implied, including, but not limited to, warranties of merchantability and fitness for a particular purpose. All liabilities arising from the supply of the information (including any liability arising in negligence) are excluded to the fullest extent permitted by law." ;

    #ncdump -h ${imod}
    echo "${imod}" >> ${0/.sh/.log}

    else
     echo " No action conversion has been taken, the convert status is: ${status}"
    fi
   else
    echo " Abort $0 because the root dir CMIP6 is not at the expected location in the path, instead we found: ${check_cmip6} at the expected location."
   fi
  done

 else
  echo
  echo " Illegal number of arguments. Needs no arguments:"
  echo "  $0"
  echo
 fi
