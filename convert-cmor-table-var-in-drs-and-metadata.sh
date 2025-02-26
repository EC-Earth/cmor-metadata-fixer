#!/usr/bin/env bash
# Thomas Reerink
#
# Run this script without arguments for examples how to call this script.
#
# This scripts converts CMIP6 data to CMIP6Plus including the DRS adjustment.
#

usage() {
  echo "Usage: $0 [-h] [-d] [-v] [-l log_file] [-c config_file] dir"
  echo "    -h : show help message"
  echo "    -d : don't duplicate data (default: duplicate data)"
  echo "    -v : verbose (default: false)"
  echo "    -l : log_file (default: ${0/.sh/.log})"
  echo "    -c : configuration file with new metadata (default: convert-config.cfg)"
  echo "    dir : directory with CMIP6 data to be converted"
  exit -1
}

# defaults
export duplicate_data=True
export verbose=False
export log_file=${0/.sh/.log}
export config='convert-config.cfg'

while getopts "hdvl:c:" opt; do
  case $opt in
  h) usage ;;
  d) duplicate_data=False ;;
  v) verbose=True ;;
  l) log_file=$OPTARG ;;
  c) config=$OPTARG ;;
  *) usage ;;
  esac
done
shift $((OPTIND - 1))

export data_dir=$1

echo "duplicate_data = $duplicate_data"
echo "verbose = $verbose"
echo "log_file = $log_file"
echo "config_file = $config"
echo "data_dir = $data_dir"

if [ "$#" -eq 1 ]; then

  function determine_dir_level() {

    local dir_path=$1

    status='nomatch'
    for i in {1..100}; do

      subdir_name=$(echo $dir_path | cut -d/ -f${i})
      if [ "$subdir_name" = "CMIP6" ]; then
        echo ${i}
        status='match'
        break
      fi

    done
    if [ "$status" = "nomatch" ]; then
      echo ${status}
    fi
  }

  export -f determine_dir_level

  function convert_cmip6_to_cmip6plus() {
    local i=$1

    dir_level=$(determine_dir_level ${i})
    if [ "${dir_level}" = "nomatch" ]; then
      echo "Abort: can not find CMIP6 in given path: ${i}"
      exit
    fi

    # Sanity check on the `CMIP6` anchor point in the CMOR DRS:
    check_cmip6=$(echo ${i} | cut -d/ -f${dir_level})
    if [ "${check_cmip6}" = "CMIP6" ]; then
      # Obtain the table and var name from the file path and name:
      table_level="$(($dir_level + 6))"
      var_level="$(($dir_level + 7))"
      table=$(echo ${i} | cut -d/ -f${table_level})
      var=$(echo ${i} | cut -d/ -f${var_level})
      table=$(echo ${i} | cut -d/ -f $((dir_level + 6)))
      var=$(echo ${i} | cut -d/ -f $((dir_level + 7)))
      experiment_id=$(echo ${i} | cut -d/ -f $((dir_level + 4)))

      # Find the equivalent table and variable name and the convert status and catch the script output in an array:
      converted_result=($(./map-cmip6-to-cmip6plus.py ${table} ${var}))
      # Put the three returned values into three separate variables:
      converted_table=${converted_result[0]}
      converted_var=${converted_result[1]}
      status=${converted_result[2]}

      if [ ${verbose} = True ]; then
        echo
        echo " Lookup CMIP6Plus equivalent of the CMIP6 ${table} ${var}:"
        echo "  ${status}"
        echo "  ${converted_table}"
        echo "  ${converted_var}"
        echo
      fi

      if [ "${status}" = "converted" ]; then
        imod=$(echo ${i} | sed -e "s/${table}/${converted_table}/g" -e "s/${var}/${converted_var}/g" -e "s/CMIP6/CMIP6Plus/g")
        mkdir -p ${imod%/*}
        if [ ${duplicate_data} = True ]; then
          # Duplicate data to CMIP6plus DRS based directory for conversion to CMIP6plus:
          rsync -a ${i} ${imod}
        else
          # Move data to CMIP6plus DRS based directory for conversion to CMIP6plus:
          mv -f ${i} ${imod}
        fi
        if [ ${var} != ${converted_var} ]; then
          ncrename -O -v ${var},${converted_var} ${imod}
          ncatted -a variable_id,global,m,c,${converted_var} -h ${imod}
        fi

        # read metadata from config file
        . $config
        new_attrs=""
        new_attrs+=" -a table_id,global,o,c,'${converted_table}'"
        new_attrs+=" -a mip_era,global,o,c,'CMIP6Plus'"
        new_attrs+=" -a parent_mip_era,global,o,c,'CMIP6Plus'"
        new_attrs+=" -a title,global,o,c,'${source_id} output prepared for'"
        new_attrs+=" -a license,global,o,c,'${license}'"
        new_attrs+=" -a further_info_url,global,d,,"
        new_attrs+=" -a institution,global,o,c,'${institution}'"
        new_attrs+=" -a comment,global,m,c,'${comment}'"
        new_attrs+=" -a description,global,o,c,'${description}'"

        new_attrs+=" -a experiment,global,o,c,'${experiment}'"
        new_attrs+=" -a experiment_id,global,o,c,'${experiment_id}'"
        new_attrs+=" -a institution_id,global,o,c,'${institution_id}'"
        new_attrs+=" -a parent_source_id,global,o,c,'${parent_source_id}'"
        new_attrs+=" -a parent_experiment_id,global,o,c,'${parent_experiment_id}'"

        new_attrs+=" -a source,global,o,c,'${source}'"
        new_attrs+=" -a source_id,global,o,c,'${source_id}'"

        # prepend to history attribute
        new_attrs+=" -a history,global,p,c,'$(date -u +%FT%XZ) ; ${history_addition}'"

        # "eval" is needed here to avoid problems with whitespace in metadata
        eval "ncatted ${new_attrs} -h -O ${imod}"

        echo "${imod}" >>${log_file}

      else
        echo " No action conversion has been taken, the convert status is: ${status}"
      fi
    else
      echo " Abort $0 because the root dir CMIP6 is not at the expected location in the path, instead we found: ${check_cmip6} at the expected location."
      echo " No conversion has been applied, the convert status is: ${status} for ${i}"
    fi
  }

  export -f convert_cmip6_to_cmip6plus

  >${log_file}

  # Check whether gnu parallel is available:
  if hash parallel 2>/dev/null; then
    echo
    echo " Run $0 in parallel mode."
    echo
    find ${data_dir} -name '*.nc' | parallel -I% convert_cmip6_to_cmip6plus %
  else
    echo
    echo " Run $0 in sequential mode."
    echo
    for i in $(find ${data_dir} -name '*.nc'); do
      convert_cmip6_to_cmip6plus $i
    done
  fi

  # Guarantee same order:
  sort ${log_file} >${log_file/.log/-sorted.log}

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
