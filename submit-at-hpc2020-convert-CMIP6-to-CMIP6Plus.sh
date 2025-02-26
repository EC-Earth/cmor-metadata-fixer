#!/usr/bin/env bash
# Thomas Reerink
#
# Convert CMIP6 cmorised data to CMIP6Plus cmorised data for any CMIP model.
#
# This scripts requires no arguments.
#

#SBATCH --time=01:05:00
#SBATCH --job-name=convert-to-cmip6plus
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --qos=nf
#SBATCH --output=stdout-conver-to-cmip6plus.%j.out
#SBATCH --error=stderr-convert-to-cmip6plus.%j.out
#SBATCH --mail-type=FAIL

# CMIP6DIR        is the directory with the cmorised data, for instance a test case: cmorMDfixer-test-data/test-set-01/CMIP6/
# METADATAFILE    is the name with the meta data correction, for instance: 

 if [ "$#" -eq 1 ]; then

   CMIP6DIR=$1

   if [ ! -d ${CMIP6DIR} ]; then echo "Error: Directory: ${CMIP6DIR}, does not exist. Abort $0" >&2; exit 1; fi

   if [   -z ${CMIP6DIR} ]; then echo "Error: Empty directory, no cmorised data in: ${CMIP6DIR}. Abort $0" >&2; exit 1; fi

   source ${PERM}/mamba/etc/profile.d/conda.sh
   conda activate cmorMDfixer

   export HDF5_USE_FILE_LOCKING=FALSE

   ./convert-cmor-table-var-in-drs-and-metadata.sh $CMIP6DIR

 else
  echo
  echo " Illegal number of arguments: this script itself requires one argument: the path of the CMIP6 cmorised data, e.g.:"
  echo "  sbatch --qos=nf --cpus-per-task=2   --account=nlchekli $0 cmorMDfixer-test-data/test-set-01/CMIP6/"
  echo "  sbatch --qos=nf --cpus-per-task=50  --account=nlchekli $0 /scratch/nktr/cmorised-results/test-all-trunk/t001/v046/CMIP6/CMIP/EC-Earth-Consortium/EC-Earth3-ESM-1/esm-hist/"
  echo "  sbatch --qos=np --cpus-per-task=128 --account=nlchekli $0 /scratch/nktr/cmorised-results/test-all-trunk/t001/v003/CMIP6/CMIP/EC-Earth-Consortium/EC-Earth3/piControl/"
  echo
  echo " Available accounts for ${USER} on hpc2020:"
  account -l $USER
  echo
 fi
