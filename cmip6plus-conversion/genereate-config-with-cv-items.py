#!/usr/bin/env python
# Thomas Reerink
#
# This script generates a config with the CV items taken from the CV file for a given model (source_id).
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

    # MAIN:

    if len(sys.argv) == 2:
  ##if len(sys.argv) == 3:

       specified_source_id  = sys.argv[1]
   ##  specified_experiment = sys.argv[2]

       # Only for separate testing of this script itself:
       print('\n Running {:} with:\n  ./{:} {:}\n'.format(os.path.basename(sys.argv[0]), os.path.basename(sys.argv[0]), sys.argv[1]))
   ##  print('\n Running {:} with:\n  ./{:} {:} {:}\n'.format(os.path.basename(sys.argv[0]), os.path.basename(sys.argv[0]), sys.argv[1], sys.argv[2]))

       # Loading the CMIP6Plus CV file:
      #input_json_file = os.path.expanduser('~/cmorize/CMIP6Plus_CVs/CVs/CMIP6Plus_CV.json')
       input_json_file = os.path.expanduser('resources/CVs/CMIP6Plus_CV.json')
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

   ##  experiments = list(cv_content['CV']['experiment_id'].keys())
   ##  if specified_experiment not in experiments:
   ##     print('\n ERROR: {} is not a valid experiment.\n'.format(specified_experiment))
   ##    #print('{} {} is not a valid experiment.\n'.format(error_message, specified_experiment))
   ##     sys.exit()


       cv_parent_source_id = specified_source_id
   ##  cv_experiment       = cv_content['CV']['experiment_id'][specified_experiment]['experiment']
   ##  cv_description = cv_content['CV']['experiment_id'][specified_experiment]['description']

   ##  cv_parent_experiment_id = cv_content['CV']['experiment_id'][specified_experiment]['parent_experiment_id'][0]
   ##  cv_activity_id = cv_content['CV']['experiment_id'][specified_experiment]['activity_id'][0]
   ## #cv_additional_allowed_model_components = cv_content['CV']['experiment_id'][specified_experiment]['additional_allowed_model_components'][:]
   ## #cv_required_model_components = cv_content['CV']['experiment_id'][specified_experiment]['required_model_components'][:]
   ##  cv_parent_activity_id = cv_content['CV']['experiment_id'][specified_experiment]['parent_activity_id'][0]
   ## #cv_sub_experiment_id = cv_content['CV']['experiment_id'][specified_experiment]['sub_experiment_id'][0]
   ## #cv_tier = cv_content['CV']['experiment_id'][specified_experiment]['tier']

       cv_esm_source = cv_content['CV']['source_id'][specified_source_id]['source'].replace("\n","\\n")
      #cv_esm_source = cv_content['CV']['source_id'][specified_source_id]['source']
       cv_esm_institution_id = cv_content['CV']['source_id'][specified_source_id]['institution_id'][0]
       cv_institution_id = cv_content['CV']['institution_id'][cv_esm_institution_id]

       cv_esm_license = cv_content['CV']['source_id'][specified_source_id]['license_info']
       cv_license = cv_content['CV']['license']
       # Manipulate the license:
       cv_license = cv_license[0].replace("produced by .*", "produced by " + cv_esm_institution_id)
       cv_license = cv_license[1:]
       cv_license = cv_license.replace("Commons .*", "Commons 4.0 (" + cv_esm_license['id'] + ")")
      #cv_license = cv_license.replace("creativecommons\\.org/.*)\\. *Consult", "creativecommons.org/licenses). Consult")
       cv_license = cv_license.replace("creativecommons\\.org/.*)\\. *Consult", "creativecommons.org/). Consult")
       cv_license = cv_license.replace(r"\.", ".")
       cv_license = cv_license.replace("*", "")
       cv_license = cv_license.replace("$", "")

       created_config_file = 'config-files/config-' + specified_source_id + '.cfg'
       with open(created_config_file, 'w') as f:
           f.write('# copy the settings from CMIP6Plus_CV.json\n')
           f.write('#\n')
           f.write('# Syntax: attr_name=attr_value\n\n')
           f.write('# List of attributes that have changed in CMIP6Plus\n\n')
           f.write('title="{} output prepared for"\n'.format(specified_source_id))
           f.write('# yes, the "title" is truncated for CMIP6Plus, something missing at the end\n')
           f.write('# see https://github.com/PCMDI/cmor/issues/776\n\n')
           f.write('institution="{}"\n\n'.format(cv_institution_id))
           f.write('source="{}"\n\n'.format(cv_esm_source))
           f.write('license="{}"\n\n\n'.format(cv_license))
           f.write('# Optionally add new attributes (not in CV)\n\n')
           f.write('comment="This experiment was done as part of OptimESM (https://optimesm-he.eu/) by XXXX"\n\n')


       print(' Created the config file:\n  {}\n'.format(created_config_file))

    else:
       print()
       print(' This scripts requires three arguments, esm source_id, experiment_id & cv item, e.g.:')
      #print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1 piControl')
       print(' ./' + os.path.basename(sys.argv[0]), 'EC-Earth3-ESM-1')
       print()


if __name__ == "__main__":
    main()
