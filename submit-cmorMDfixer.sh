#!/usr/bin/env bash
# Thomas Reerink
#
# Fix metadata errors in cmorised data for any CMIP model.
#
# This scripts requires no arguments.
#

#SBATCH --time=00:05:00
#SBATCH --job-name=cmorMDfixer
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=64
#SBATCH --qos=nf
#SBATCH --output=stdout-cmorisation.%j.out
#SBATCH --error=stderr-cmorisation.%j.out
#SBATCH --account=nlchekli
#SBATCH --mail-type=FAIL

# CMORISEDDIR is the directory with the cmorised data
# METADATAFILE    is the name with the meta data correction, for instance: metadata-correction-cases/knmi-metadata-corrections-piControl.json


# Example running directly from the command line on the main node:
# ./cmorMDfixer.py --verbose --dry --forceid --olist --npp 1 /scratch/nktr/cmorised-results/cmorMDfixer-test-data/test-set-01/CMIP6


 if [ "$#" -eq 0 ]; then

   CMORISEDDIR=cmorMDfixer-test-data/test-set-01/CMIP6
   METADATAFILE=metadata-correction-cases/knmi-metadata-corrections-piControl.json
   if [ -z "$CMORISEDDIR" ]; then echo "Error: Empty directory, no cmorised data in: " $CMORISEDDIR ", aborting" $0 >&2; exit 1; fi

   source ${PERM}/mamba/etc/profile.d/conda.sh
   conda activate cmorMDfixer

   export HDF5_USE_FILE_LOCKING=FALSE

   ./cmorMDfixer.py --verbose         \
                   --forceid          \
                   --olist            \
                   --npp         64   \
                   $METADATAFILE      \
                   $CMORISEDDIR

#  ./cmorMDfixer.py --verbose         \
#                  --dry              \
#                  --keepid           \
#                  --olist            \
#                  --npp         64   \
#                  $METADATAFILE      \
#                  $CMORISEDDIR

 else
  echo
  echo "  Illegal number of arguments: this script itself requires no arguments. Thus run:"
  echo "   sbatch  $0"
  echo
 fi
