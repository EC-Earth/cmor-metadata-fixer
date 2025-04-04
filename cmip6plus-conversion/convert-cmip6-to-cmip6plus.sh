#!/usr/bin/env bash
# Thomas Reerink
#
# Run this script without arguments for examples how to call this script.
#
# This scripts converts CMIP6 data to CMIP6Plus including the DRS adjustment.
#

usage() {
  echo "Usage: $0 [-h] [-d] [-v] [-p output_path] [-o] [-s switch_model] [-l log_file] [-c config_file] DIR"
  echo "    -h : show help message"
  echo "    -d : don't duplicate data (default: copy data)"
  echo "    -v : switch on verbose (default: off)"
  echo "    -p : specify an output path (default: ${output_path})"
  echo "    -f : faster, taking several attributes from config instead directly from the CV file (default: ${fast_mode})"
  echo "    -o : overwrite existing files (default: ${overwrite})"
  echo "    -s : switch to another model (default: ${switch_model}), only affects unregistered cases"
  echo "    -l : log_file (default: ${log_file})"
  echo "    -c : configuration file (default: ${config})"
  echo "    DIR : path to CMIP6 directory"
  exit -1
}

# defaults
export duplicate_data=True
export verbose=False
export log_file=${0/.sh/.log}
export config='config-files/convert-ecearth.cfg'
export output_path=False
export fast_mode=False
export overwrite=False
export switch_model=False

option_list=""
while getopts "hdvp:fos:l:c:" opt; do
  option_list+=" -"$opt" "$OPTARG
  case $opt in
  h) usage ;;
  d) duplicate_data=False ;;
  v) verbose=True ;;
  p) output_path=$OPTARG ;;
  f) fast_mode=True ;;
  o) overwrite=True ;;
  s) switch_model=$OPTARG ;;
  l) log_file=$OPTARG ;;
  c) config=$OPTARG ;;
  *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [ "${switch_model}" != False ] && [ ${fast_mode} != False ]; then
 echo
 echo -e "\e[1;31m Error:\e[0m"" Sorry option -s is not compatible with option -f"
 echo
 exit 1
fi

export data_dir=$1

if [ ${verbose} = True ]; then
   echo
   echo " duplicate data = $duplicate_data"
   echo " verbose = $verbose"
   echo " output path = $output_path"
   echo " fast mode = $fast_mode"
   echo " overwrite = $overwrite"
   echo " switch model = $switch_model"
   echo " log file name = $log_file"
   echo " config file name = $config"
   echo " input data dir = $data_dir"
fi

export nomatch_file=${log_file/.log/-nomatch.log}
export unregistered_file=${log_file/.log/-unregistered.log}

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

        # Obtain the experiment_id & source_id name from the file path and name:
        experiment_id=$(echo ${i} | cut -d/ -f $((dir_level + 4)))
        source_id=$(echo ${i} | cut -d/ -f $((dir_level + 3)))

        # Check whether a model has a CMIP6Plus registration:
        cv_experiment=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_experiment) | cut -d = -f 2- | trim)
        error_in_cv_request=${cv_experiment:0:6}

        # Continue conversion towards CMIP6 Plus in case no error is detected or in case no error is detected after switching source_id:
        continue_conversion=True
        if [ "${error_in_cv_request}" = "ERROR:" ]; then
         continue_conversion=False

         # Only allowed in case a model is not registered, to prevent other unintended cases.
         if [ "${switch_model}" != False ]; then

          # Check whether the model specified with the -s option has a CMIP6Plus registration:
          cv_experiment_switch=$(echo $(./request-cv-item.py ${switch_model} ${experiment_id} cv_experiment) | cut -d = -f 2- | trim)
          error_in_cv_request=${cv_experiment_switch:0:6}
          if [ "${error_in_cv_request}" = "ERROR:" ]; then
           echo -e "\e[1;31m Error:\e[0m"" The ${switch_model} specified with the -s option is not registred, therefore reject this switch."
          else
           continue_conversion=True
          #echo " Switch model name (due to -s option) from ${source_id} to ${switch_model}."
           # Replace all occurences:
           imod=${imod//${source_id}/${switch_model}}
           source_id=${switch_model}
           if [ ${verbose} = True ]; then
            echo " Switch model name: ${imod}"
           fi
          fi
        #else
        # echo -e "\e[1;31m Error:\e[0m"" ${cv_experiment:7:-1} for CMIP6Plus."
         fi
        fi

        if [ ${continue_conversion} = True ]; then
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
           if [ ${fast_mode} = False ]; then
            cv_description=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_description)    | cut -d = -f 2- | trim)
            cv_experiment=$( echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_experiment)     | cut -d = -f 2- | trim)
            cv_license=$(    echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_license)        | cut -d = -f 2- | trim)
            cv_institution=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_institution_id) | cut -d = -f 2- | trim)
            cv_source=$(     echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_esm_source)     | cut -d = -f 2- | trim)
            # Stupid fixes for newline & single spaces in source text content (probably leaving this differences won't stop publishing):
            for component in {'aerosol','atmos','atmosChem','land','landIce','ocean','ocnBgchem','seaIce'}; do 
             cv_source=${cv_source/${component}/"\n${component}"}
            done
            cv_source=$(echo "${cv_source}" | sed -e 's/ \\n/\\n/g')
            cv_source=$(echo "${cv_source}" | sed -e 's/:\\n/: \\n/g')
            cv_source=$(echo "${cv_source}" | sed -e 's/surroundings)\\n/surroundings) \\n/g')  # dirty adhoc fix for identical result

            cv_title="${source_id} output prepared for"            # The CMIP6Plus tables have an truncation error at the end of the title, see https://github.com/PCMDI/cmor/issues/776
           #cv_title="${source_id} output prepared for CMIP6Plus"  # Actual correct case
           else
            case $experiment_id in
            esm-piControl)
              cv_experiment="pre-industrial control simulation with preindustrial CO2 emissions defined (CO2 emission-driven)"
              cv_description="DECK: control (emission-driven)"
              ;;
            esm-hist)
              cv_experiment="all-forcing simulation of the recent past with atmospheric CO2 concentration calculated (CO2 emission-driven)"
              cv_description="CMIP6 historical (CO2 emission-driven)"
              ;;
            *)
              echo -e "\e[1;31m Error:\e[0m"" Settings for experiment ${experiment_id} not defined yet for the fast mode."
              exit -1
              ;;
            esac
           fi

           # Catch errors for cases in which a CMIP6 configuration or experiment is encountered which does not have an CMIP6Plus registration:
           if [ "${cv_experiment:0:6}" = "ERROR:" ]; then
            # This case should not longer occur.
            echo -e "\e[1;31m Error:\e[0m"" ${cv_experiment:7:-1} for CMIP6Plus. The experiment, institution, source, license & description attributes contain an error for $imod"
           fi

           new_attrs_local+=" -a table_id,global,o,c,'${converted_table}'"
           new_attrs_local+=" -a description,global,o,c,'${cv_description}'"
           new_attrs_local+=" -a experiment,global,o,c,'${cv_experiment}'"
           if [ ${fast_mode} = False ]; then
            new_attrs_local+=" -a license,global,o,c,'${cv_license}'"
            new_attrs_local+=" -a institution,global,o,c,'${cv_institution}'"
            new_attrs_local+=" -a source,global,o,c,'${cv_source}'"
            new_attrs_local+=" -a title,global,o,c,'${cv_title}'"
            if [ "${switch_model}" != False ]; then
             new_attrs_local+=" -a source_id,global,o,c,'${source_id}'"
             # Adjusting in this case the parent_source_id might be not always the preffered situation (maybe deactive again?):
             cv_parent_source_id=$(echo $(./request-cv-item.py ${source_id} ${experiment_id} cv_parent_source_id) | cut -d = -f 2- | trim)
             new_attrs_local+=" -a parent_source_id,global,o,c,'${cv_parent_source_id}'"
            #echo " Note that the parent_source_id has been set to ${cv_parent_source_id}."
             echo " Switch model name (due to -s option) from ${source_id} to ${switch_model}. Note that the parent_source_id has been set to ${cv_parent_source_id}."
            fi
           fi

           # prepend history attribute
           new_attrs_local+=" -a history,global,p,c,'$(date -u +%FT%XZ) ; The convert-cmip6-to-cmip6plus.sh script has been applied.;\n'"
          #new_attrs_local+=" -a history,global,p,c,'$(date -u +%FT%XZ) ; The cmorMDfixer CMIP6 => CMIP6Plus convertscript has been applied.;\n'"

           # "eval" is needed here to avoid problems with whitespace in metadata
           eval "ncatted ${new_attrs_local} -h -O ${imod}"

           echo "${imod}" >>${log_file}
         else
           echo "${imod} already exists and overwrite=$overwrite" | tee -a ${log_file}
         fi

        else
         echo -e "\e[1;31m Error:\e[0m"" ${cv_experiment:7:-1} for CMIP6Plus."
         echo -e "${cv_experiment:7:-1} for CMIP6Plus for ${i}" >> ${unregistered_file}
        fi

      else
        echo -e "\e[1;31m Error:\e[0m"" No conversion for ${table} ${var} has been taken, the convert status is: ${status}"
        echo " No CMIP6Plus table var match for ${i}" >> ${nomatch_file}
      fi
    else
      echo " Abort $0 because the root dir CMIP6 is not at the expected location in the path, instead we found: ${check_cmip6} at the expected location."
      echo " No conversion has been applied, the convert status is: ${status} for ${i}"
    fi
  }

  export -f convert_cmip6_to_cmip6plus

  # Clean log_file
  >${log_file}
  >${nomatch_file}
  >${unregistered_file}

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

  if [ ${fast_mode} != False ]; then
   for check_avail_atr in {'license="','institution="','source="','title="'}; do
    presence_test=$(grep -e ${check_avail_atr} ${config})
    if [[ ! ${presence_test} ]]; then
     echo -e "\e[1;31m Error:\e[0m"" The ${check_avail_atr:0:-2} attribute is not defined in your config file ${config} wich should be the case with the fast mode -f option."
     exit 1
    fi
   done
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
  sort ${log_file}          >${log_file/.log/-sorted.log}
  sort ${nomatch_file}      >${nomatch_file/.log/-sorted.log}
  sort ${unregistered_file} >${unregistered_file/.log/-sorted.log}
  echo
  if [ ! -s ${log_file} ]; then
   rm -f ${log_file} ${log_file/.log/-sorted.log}
  else
   echo " Finished, the converted files are listed in the log file: ${log_file/.log/-sorted.log}"
  fi
  if [ ! -s ${nomatch_file} ]; then
   rm -f ${nomatch_file} ${nomatch_file/.log/-sorted.log}
  else
   echo " The no match encountered cases are listed in the log file: ${nomatch_file/.log/-sorted.log}"
  fi
  if [ ! -s ${unregistered_file} ]; then
   rm -f ${unregistered_file} ${unregistered_file/.log/-sorted.log}
  else
   echo " The unregistered encountered cases are listed in the log file: ${unregistered_file/.log/-sorted.log}"
  fi
  echo
  rm -f ${log_file} ${nomatch_file} ${unregistered_file}

else
  echo
  echo " Illegal number of arguments. Needs one argument, the data dir with your cmorised CMIP6 data:"
  echo "  $0 ../cmorMDfixer-test-data/test-set-02/CMIP6/"
  echo
fi
