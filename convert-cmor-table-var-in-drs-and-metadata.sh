#!/usr/bin/env bash
# Thomas Reerink
#
# Run this script without arguments for examples how to call this script.
#
# This scripts converts CMIP6 data to CMIP6Plus including the DRS adjustment.
#

usage() {
  echo "Usage: $0 [-h] [-d] [-v] [-o] [-l log_file] [-c config_file] DIR"
  echo "    -h : show help message"
  echo "    -d : don't duplicate data (default: copy data)"
  echo "    -v : switch on verbose (default: off)"
  echo "    -o : overwrite existing files (default: ${overwrite})"
  echo "    -l : log_file (default: ${log_file})"
  echo "    -c : configuration file (default: ${config})"
  echo "    DIR : path to CMIP6 directory"
  exit -1
}

# defaults
export duplicate_data=True
export verbose=False
export log_file=${0/.sh/.log}
export config='convert-ecearth.cfg'
export overwrite=false

option_list=""
while getopts "hdvol:c:" opt; do
  option_list+=" -"$opt
  case $opt in
  h) usage ;;
  d) duplicate_data=False ;;
  v) verbose=True ;;
  o) overwrite=true ;;
  l) log_file=$OPTARG ;;
  c) config=$OPTARG ;;
  *) usage ;;
  esac
done
shift $((OPTIND - 1))

export data_dir=$1

if [ ${verbose} = True ]; then
   echo "duplicate_data = $duplicate_data"
   echo "overwrite = $overwrite"
   echo "verbose = $verbose"
   echo "log_file = $log_file"
   echo "config_file = $config"
   echo "data_dir = $data_dir"
fi

if [ "$#" -eq 1 ]; then

  function determine_dir_level() {

    local dir_path=$1
    cmip6_path=''

    status='nomatch'
    for i in {1..100}; do

      subdir_name=$(echo $dir_path | cut -d/ -f${i})
      cmip6_path+="${subdir_name}/"
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

  function get_new_attrs() {
    # helper to trim leading and trailing spaces
    trim() {
      sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
    }
    # create sequence of ncatted commands from the config file
    export new_attrs=''
    # common updates
    new_attrs+=" -a mip_era,global,o,c,'CMIP6Plus'"
    new_attrs+=" -a parent_mip_era,global,o,c,'CMIP6Plus'"
    new_attrs+=" -a further_info_url,global,d,,"
    while read -r line; do
      # remove comments and split
      ll=${line%#*}
      ll_lhs=$(echo $ll | cut -d = -f 1 | trim)
      ll_rhs=$(echo $ll | cut -d = -f 2- | trim)
      if [ "$ll_lhs" != "$ll_rhs" ]; then
        # remove quotation marks
        eval "rhs=$ll_rhs"
        new_attrs+=" -a ${ll_lhs},global,o,c,'${rhs}'"
      fi
    done <$config
  }

  function convert_cmip6_to_cmip6plus() {
    local i=$1

    dir_level=$(determine_dir_level ${i})
    if [ "${dir_level}" = "nomatch" ]; then
      echo "Abort: can not find CMIP6 in given path: ${i}"
      exit
    fi

    # load new attributes in a local variable
    local new_attrs_local=$new_attrs

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
        echo " Lookup CMIP6Plus equivalent of the CMIP6 ${table} ${var}: ${converted_table} ${converted_var} ${status}"
        echo
      fi

      if [ "${status}" != "nomatch" ]; then
        imod=$(echo ${i} | sed -e "s/${table}/${converted_table}/g" -e "s/${var}/${converted_var}/g" -e "s/CMIP6/CMIP6Plus/g")

        # check if file already exists
        # if it exists force cp/mv only if -o has been set
        if [ ! -f $imod ] || $overwrite; then
          mkdir -p ${imod%/*}
          if [ ${duplicate_data} = True ]; then
            # Duplicate data to CMIP6plus DRS based directory for conversion to CMIP6plus:
            rsync -a ${i} ${imod}
          else
            # Move data to CMIP6plus DRS based directory for conversion to CMIP6plus:
            mv -f ${i} ${imod}
          fi
          if [ ${var} != ${converted_var} ]; then
            ncrename -O -h -v ${var},${converted_var} ${imod}
            new_attrs_local+=" -a variable_id,global,m,c,${converted_var}"
          fi

          # add attrs to list
          new_attrs_local+=" -a table_id,global,o,c,'${converted_table}'"
          case $experiment_id in
          esm-piControl)
            experiment="pre-industrial control simulation with preindustrial CO2 emissions defined (CO2 emission-driven)"
            description="DECK: control (emission-driven)"
            ;;
          esm-hist)
            experiment="all-forcing simulation of the recent past with atmospheric CO2 concentration calculated (CO2 emission-driven)"
            description="CMIP6 historical (CO2 emission-driven)"
            ;;
          *)
            echo "*** ERROR: settings for experiment $experiment_id not defined yet ***"
            exit -1
            ;;
          esac
          new_attrs_local+=" -a description,global,o,c,'${description}'"
          new_attrs_local+=" -a experiment,global,o,c,'${experiment}'"

          # prepend history attribute
          new_attrs_local+=" -a history,global,p,c,'$(date -u +%FT%XZ) ; The cmorMDfixer CMIP6 => CMIP6Plus convertscript has been applied.;\n'"

          # "eval" is needed here to avoid problems with whitespace in metadata
          eval "ncatted ${new_attrs_local} -h -O ${imod}"

          echo "${imod}" >>${log_file}
        else
          echo "${imod} already exists and overwrite=$overwrite" | tee -a ${log_file}
        fi

      else
        echo " No action conversion has been taken, the convert status is: ${status}"
      fi
    else
      echo " Abort $0 because the root dir CMIP6 is not at the expected location in the path, instead we found: ${check_cmip6} at the expected location."
      echo " No conversion has been applied, the convert status is: ${status} for ${i}"
    fi
  }

  export -f convert_cmip6_to_cmip6plus

  # Clean log_file
  >${log_file}

  # First sanity check
  check=$(determine_dir_level $data_dir)
  if [ "$check" = "nomatch" ]; then
    echo "Abort : no path to CMIP6 directory in ${data_dir}"
    exit -1
  else
    if [ ${verbose} = True ]; then
       echo
       echo "The CMIP6 directroy is at directory level: ${check}"
       echo "Found CMIP6 directory ${cmip6_path}"
       echo "Saving converted data in $(echo ${data_dir} | cut -d/ -f1-$((${check}-1)))/CMIP6Plus"
    fi
  fi

  # load list with new attributes
  get_new_attrs

  # Check whether gnu parallel is available:
  if hash parallel 2>/dev/null; then
    echo
    echo " Run in parallel mode:"
    echo "  $0$option_list $@"
    echo
    find ${data_dir} -name '*.nc' | parallel -I% convert_cmip6_to_cmip6plus %
  else
    echo
    echo " Run in sequential mode."
    echo "  $0$option_list $@"
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
