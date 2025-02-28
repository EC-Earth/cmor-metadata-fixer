#!/usr/bin/env bash
# Thomas Reerink
#
# Run this script without arguments for examples how to call this script.
#
# This scripts converts CMIP6 data to CMIP6Plus including the DRS adjustment.
#

usage() {
  echo "Usage: $0 [-h] [-d] [-v] [-p output_path] [-o] [-l log_file] [-c config_file] DIR"
  echo "    -h : show help message"
  echo "    -d : don't duplicate data (default: copy data)"
  echo "    -v : switch on verbose (default: off)"
  echo "    -p : specify an output path (default: ${output_path})"
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
export output_path=False
export overwrite=False

option_list=""
while getopts "hdvp:ol:c:" opt; do
  option_list+=" -"$opt" "$OPTARG
  case $opt in
  h) usage ;;
  d) duplicate_data=False ;;
  v) verbose=True ;;
  p) output_path=$OPTARG ;;
  o) overwrite=True ;;
  l) log_file=$OPTARG ;;
  c) config=$OPTARG ;;
  *) usage ;;
  esac
done
shift $((OPTIND - 1))

export data_dir=$1

if [ ${verbose} = True ]; then
   echo
   echo " duplicate_data = $duplicate_data"
   echo " verbose = $verbose"
   echo " output_path = $output_path"
   echo " overwrite = $overwrite"
   echo " log_file = $log_file"
   echo " config_file = $config"
   echo " data_dir = $data_dir"
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

  # helper to trim leading and trailing spaces
  function trim() {
    sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
  }

  export -f trim

  function get_new_attrs() {

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
      table=$(echo ${i} | cut -d/ -f $((dir_level + 6)))
      var=$(echo ${i} | cut -d/ -f $((dir_level + 7)))
      experiment_id=$(echo ${i} | cut -d/ -f $((dir_level + 4)))
      source_id=$(echo ${i} | cut -d/ -f $((dir_level + 3)))

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

        if [ "${output_path}" != False ]; then
         pre_path_orig=$(echo ${imod} | cut -d/ -f1-$((${dir_level}-1)))
         pre_path_new=${output_path}
         if [ ${verbose} = True ]; then
          echo " The pre path has been changed for the output from $pre_path_orig => $pre_path_new"
         fi
         imod=${imod/$pre_path_orig/$pre_path_new}
        fi

        # check if file already exists
        # if it exists force cp/mv only if -o has been set
        if [ ! -f $imod ] || [ $overwrite = True ]; then
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
          license=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_license) | cut -d = -f 2- | trim)
          description=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_description) | cut -d = -f 2- | trim)
          experiment=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_experiment) | cut -d = -f 2- | trim)

          institution=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_institution_id) | cut -d = -f 2- | trim)
          source=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_esm_source) | cut -d = -f 2- | trim)
          # Stupid fixes for newline & single spaces in source text content (probably leaving this differences won't stop publishing):
          for component in {'aerosol','atmos','atmosChem','land','landIce','ocean','ocnBgchem','seaIce'}; do 
           source=${source/${component}/"\n${component}"}
          done
          source=$(echo "$source" | sed -e 's/ \\n/\\n/g')
          source=$(echo "$source" | sed -e 's/:\\n/: \\n/g')
          source=$(echo "$source" | sed -e 's/surroundings)\\n/surroundings) \\n/g')  # dirty adhoc fix for identical result

          title="${source_id} output prepared for"            # The CMIP6Plus tables have an truncation error at the end of the title, see https://github.com/PCMDI/cmor/issues/776
         #title="${source_id} output prepared for CMIP6Plus"  # Actual correct case

          new_attrs_local+=" -a table_id,global,o,c,'${converted_table}'"
          new_attrs_local+=" -a description,global,o,c,'${description}'"
          new_attrs_local+=" -a experiment,global,o,c,'${experiment}'"
          new_attrs_local+=" -a license,global,o,c,'${license}'"
          new_attrs_local+=" -a institution,global,o,c,'${institution}'"
          new_attrs_local+=" -a source,global,o,c,'${source}'"
          new_attrs_local+=" -a title,global,o,c,'${title}'"

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
       echo " The CMIP6 directroy is at directory level: ${check}"
       echo " Found CMIP6 directory ${cmip6_path}"
       echo " Saving converted data in $(echo ${data_dir} | cut -d/ -f1-$((${check}-1)))/CMIP6Plus"
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
