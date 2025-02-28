#!/usr/bin/env python
# Thomas Reerink
#
# This script prints a requested CV item.
#
# Run this script without arguments for examples how to call this script.
#
# This script is part of the subpackage genecec (GENerate EC-Eearth Control output files)
# which is part of ece2cmor3.


import sys
import os
import json
import os.path                                                # for checking file existence with: os.path.isfile
from os.path import expanduser                                # Enable to go to the home dir: ~

error_message   = ' \033[91m' + 'Error:'   + '\033[0m'        # Red    error   message
warning_message = ' \033[93m' + 'Warning:' + '\033[0m'        # Yellow warning message

# Main program
def main():

    # FUNCTION DEFINITIONS:



    # MAIN:

    if len(sys.argv) == 4:

       specified_source_id  = sys.argv[1]
       specified_experiment = sys.argv[2]
       requested_cv_item    = sys.argv[3]

       # Only for separate testing of this script itself:
      #print('\n Running {:} with:\n  ./{:} {:} {:}\n'.format(os.path.basename(sys.argv[0]), os.path.basename(sys.argv[0]), sys.argv[1], sys.argv[2]))

       # Loading the CMIP6Plus CV file:
       input_json_file = os.path.expanduser('~/cmorize/CMIP6Plus_CVs/CVs/CMIP6Plus_CV.json')
       if os.path.isfile(input_json_file) == False:
        print(error_message, ' The CV file ', input_json_file, ' does not exist.\n')
        sys.exit()

       with open(input_json_file) as json_file:
        cv_content = json.load(json_file)
       json_file.close()


       # Check whether arguments are known within the CV:
       esms = list(cv_content['CV']['source_id'].keys())
       if specified_source_id not in esms:
          print('\n ERROR: {} is not a valid ESM source_id.\n'.format(specified_source_id))
         #print('{} {} is not a valid ESM source_id.\n'.format(error_message, specified_source_id))
          sys.exit()

       experiments = list(cv_content['CV']['experiment_id'].keys())
       if specified_experiment not in experiments:
          print('\n ERROR: {} is not a valid experiment.\n'.format(specified_experiment))
         #print('{} {} is not a valid experiment.\n'.format(error_message, specified_experiment))
          sys.exit()


       if requested_cv_item == 'cv_parent_source_id':
        content_requested_cv_item = specified_source_id
       elif requested_cv_item == 'cv_experiment':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['experiment']
       elif requested_cv_item == 'cv_description':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['description']

       elif requested_cv_item == 'cv_parent_experiment_id':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['parent_experiment_id'][0]
       elif requested_cv_item == 'cv_activity_id':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['activity_id'][0]
       elif requested_cv_item == 'cv_additional_allowed_model_components':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['additional_allowed_model_components'][:]
       elif requested_cv_item == 'cv_required_model_components':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['required_model_components'][:]
       elif requested_cv_item == 'cv_parent_activity_id':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['parent_activity_id'][0]
       elif requested_cv_item == 'cv_sub_experiment_id':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['sub_experiment_id'][0]
       elif requested_cv_item == 'cv_tier':
        content_requested_cv_item = cv_content['CV']['experiment_id'][specified_experiment]['tier']

       elif requested_cv_item == 'cv_esm_source':
       #content_requested_cv_item = cv_content['CV']['source_id'][specified_source_id]['source']
        content_requested_cv_item = cv_content['CV']['source_id'][specified_source_id]['source'].replace("\n","")
       elif requested_cv_item == 'cv_esm_institution_id':
        content_requested_cv_item = cv_content['CV']['source_id'][specified_source_id]['institution_id'][0]
       elif requested_cv_item == 'cv_institution_id':
        cv_esm_institution_id = cv_content['CV']['source_id'][specified_source_id]['institution_id'][0]
        content_requested_cv_item = cv_content['CV']['institution_id'][cv_esm_institution_id]

       elif requested_cv_item == 'cv_license':
       #content_requested_cv_item = cv_content['CV']['license']
        cv_esm_institution_id = cv_content['CV']['source_id'][specified_source_id]['institution_id'][0]
        cv_esm_license = cv_content['CV']['source_id'][specified_source_id]['license_info']
        cv_license = cv_content['CV']['license']
        # Manipulate the license:
        cv_license = cv_license[0].replace("produced by .*", "produced by " + cv_esm_institution_id)
        cv_license = cv_license[1:]
        cv_license = cv_license.replace("Commons .*", "Commons 4.0 (" + cv_esm_license['id'] + ")")
        cv_license = cv_license.replace("creativecommons\\.org/.*)\\. *Consult", "creativecommons.org/licenses). Consult")
        cv_license = cv_license.replace(r"\.", ".")
        cv_license = cv_license.replace("*", "")
        content_requested_cv_item = cv_license.replace("$", "")

       else:
        content_requested_cv_item = 'nomatch'
       #print('\n ERROR: {} is not a valid requested_cv_item.\n'.format(requested_cv_item))
       #print('{} {} is not a valid requested_cv_item.\n'.format(error_message, requested_cv_item))

       print('{}'.format(content_requested_cv_item))

      # Call from bash:
      # echo
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_parent_source_id                   `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_experiment                         `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_description                        `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_parent_experiment_id               `; echo $cv_item
      # echo
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_esm_source                         `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_esm_institution_id                 `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_institution_id                     `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_license                            `; echo $cv_item
      # echo
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_activity_id                        `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_additional_allowed_model_components`; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_required_model_components          `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_parent_activity_id                 `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_sub_experiment_id                  `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 piControl cv_tier                               `; echo $cv_item
      # echo
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_parent_source_id                   `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_experiment                         `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_description                        `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_parent_experiment_id               `; echo $cv_item
      # echo
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_esm_source                         `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_esm_institution_id                 `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_institution_id                     `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_license                            `; echo $cv_item
      # echo
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_activity_id                        `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_additional_allowed_model_components`; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_required_model_components          `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_parent_activity_id                 `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_sub_experiment_id                  `; echo $cv_item
      # cv_item=`./request-cv-item.py EC-Earth3-ESM-1 esm-hist cv_tier                               `; echo $cv_item
      # echo

    else:
       print()
       print(' This scripts requires three arguments, esm source_id, experiment_id & cv item, e.g.:')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 piControl cv_parent_source_id                   ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 piControl cv_description                        ')
       print()
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_parent_source_id                   ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_experiment                         ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_description                        ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_parent_experiment_id               ')
       print()
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_esm_source                         ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_esm_institution_id                 ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_institution_id                     ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_license                            ')
       print()
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_activity_id                        ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_additional_allowed_model_components')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_required_model_components          ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_parent_activity_id                 ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_sub_experiment_id                  ')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 esm-hist  cv_tier                               ')
       print()


if __name__ == "__main__":
    main()
