#!/usr/bin/env bash
# Thomas Reerink
#
# Fix metadata errors in cmorised data for any CMIP model.
#
# This scripts requires no arguments.
#

#SBATCH --time=01:05:00
#SBATCH --job-name=convert-to-cmip6plus
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --qos=nf
#SBATCH --output=stdout-cmorisation.%j.out
#SBATCH --error=stderr-cmorisation.%j.out
#SBATCH --account=nlchekli
#SBATCH --mail-type=FAIL

# CMORISEDDIR is the directory with the cmorised data
# METADATAFILE    is the name with the meta data correction, for instance: metadata-correction-cases/knmi-metadata-corrections-piControl.json


# Example running directly from the command line on the main node:
# ./convert-cmor-table-var-in-drs-and-metadata.sh cmorMDfixer-test-data/test-set-01/CMIP6/

 if [ "$#" -eq 1 ]; then

  #CMIP6DIR=cmorMDfixer-test-data/test-set-01/CMIP6/
   CMIP6DIR=$1

   if [ -z "$CMIP6DIR" ]; then echo "Error: Empty directory, no cmorised data in: " $CMIP6DIR ", aborting" $0 >&2; exit 1; fi

   source ${PERM}/mamba/etc/profile.d/conda.sh
   conda activate cmorMDfixer

   export HDF5_USE_FILE_LOCKING=FALSE

   ./convert-cmor-table-var-in-drs-and-metadata.sh $CMIP6DIR

 else
  echo
  echo "  Illegal number of arguments: this script itself requires no arguments. Thus run:"
  echo "   sbatch  $0 cmorMDfixer-test-data/test-set-01/CMIP6/"
  echo
 fi
