# cmor-metadata-fixer
CMOR metadata fixer for cmorised output of any CMIP model

Guidelines how to use the `cmorMDfixer` can be found below.

## Required python packages:

* netCDF4

## 1. Installation

#### Installation via Mamba (strongly recommended):
With the `Mamba` package manager all the python packages can be installed within one go. For instance, this is certainly beneficial at HPC systems where permissions to install complementary python packages to the default python distribution are lacking.

##### Define a mambapath & two aliases

First, define a `mambapath` and two aliases in a `.bashrc` file for later use:
 ```shell
 mambapath=${HOME}/mamba/
 alias activatemamba='source ${mambapath}/etc/profile.d/conda.sh'
 alias activatecmorMDfixer='activatemamba; conda activate cmorMDfixer'
 ```

##### If Mamba is not yet installed:

Download [mamba](https://github.com/conda-forge/miniforge/releases/latest/) by using `wget` and install it via the commandline with `bash`:
 ```shell
 # Check whether mambapath is set:
 echo ${mambapath}
 # Create a backup of an eventual mamba install (and environments) to prevent an accidental overwrite:
 if [ -d ${mambapath} ]; then backup_label=backup-`date +%d-%m-%Y`; mv -f  ${mambapath} ${mambapath/mamba/mamba-${backup_label}}; fi

 # Download & install mamba:
 mkdir -p ${HOME}/Downloads; cd ${HOME}/Downloads/
 wget "https://github.com/conda-forge/miniforge/releases/latest/download/MIniforge3-$(uname)-$(uname -m).sh"
 bash MIniforge3-$(uname)-$(uname -m).sh -b -u -p ${mambapath}

 # Update mamba:
 activatemamba
 mamba update -y --name base mamba
 ```

##### Download the `cmor-metadata-fixer` by a git checkout

For example we create the directoy ${HOME}/cmorize/ and checkout the cmor-metadata-fixer by:
```shell
git clone https://github.com/EC-Earth/cmor-metadata-fixer.git  # For a simple HTTPS checkout
git clone git@github.com:EC-Earth/cmor-metadata-fixer.git      # For a SSH checkout (enabling "git push")
```

##### Creating a conda environment and installing cmorMDfixer therein:

```shell
activatemamba                             # The mamba-activate alias (as defined above)
cd ${HOME}/cmorize/cmor-metadata-fixer    # Navigate to the cmor-metadata-fixer root directory
mamba env create -f environment.yml       # Create the python environment (for linux & mac os)
conda activate cmorMDfixer                # Here conda is still used instead of mamba
conda deactivate                          # Deactivating the active (here cmorMDfixer) environment
```

## 2. Run cmorMDfixer

### Test cmorMDfixer

##### Running the cmorMDfixer inside the conda environment:
```shell
 # Activate the cmorMDfixer environment:
 activatecmorMDfixer                      # The alias as defined above

 # Run the help of the cmorMDfixer, it lists its argument options:
 ./cmorMDfixer.py -h

 # A dry-run example with the test script:
 ./test-cmorMDfixer.sh dry
 # A real example with the test script in which the test data is modified:
 ./test-cmorMDfixer.sh modify
 # Clean and revert the changes made above:
 ./test-cmorMDfixer.sh clean

 # A real example with the cmorMDfixer-safe-mode-wrapper.sh using the test data:
 ./cmorMDfixer-safe-mode-wrapper.sh 1 metadata-correction-cases/knmi-metadata-corrections-piControl.json cmorMDfixer-test-data/test-set-01/CMIP6
 # See what happens when this is repeated on corrected data:
 rm -f list-of-modified-files*.txt
 ./cmorMDfixer-safe-mode-wrapper.sh 1 metadata-correction-cases/knmi-metadata-corrections-piControl.json cmorMDfixer-test-data/test-set-01/CMIP6
 # Clean and revert the changes made above:
 ./test-cmorMDfixer.sh clean
 rm -f list-of-modified-files*.txt cmorMDfixer-messages-*.log

 # Deactivating the active (here cmorMDfixer) environment
 conda deactivate
```

### Apply cmorMDfixer on your data (possibly on published data at the ESGF node)


##### Option 1: Running the cmorMDfixer:

```shell

 # Activate the cmorMDfixer conda environment:
 activatecmorMDfixer                      # The mamba-activate alias (as defined above)
 cd ${HOME}/cmorize/cmor-metadata-fixer   # Navigate to the cmor-metadata-fixer root directory

 # Replace with the cmorMDfixer.py all cmor attribute values listed in the metadata-corrections.json file
 # on all files within the CMIP6 directory:
 ./cmorMDfixer.py --verbose --forceid --olist log-dir --npp 1 metadata-corrections.json CMIP6/

 # Deactivating the active (here cmorMDfixer) environment
 conda deactivate
```

##### Option 2: Alternatively, use the `cmorMDfixer-safe-mode-wrapper.sh` script:

The `cmorMDfixer-safe-mode-wrapper.sh` script will only apply changes if at least one occurence is detected in the entire dataset. In case one occurence is detected the script will continue to apply the changes. Additional checks will be applied to check for interuptions during running the script.
```
 # Activate the cmorMDfixer conda environment:
 activatecmorMDfixer                      # The mamba-activate alias (as defined above)

 ./cmorMDfixer-safe-mode-wrapper.sh 1 metadata-corrections.json CMIP6/

 conda deactivate
```

##### Option 3: Use a submit script:

The `submit-cmorMDfixer.sh` script is an `sbatch` template for a submit script which needs adjustments of all the paths and possibly adjustent of the cmorMDfixer arguments depending on the preferences of the user. The script can be called (it activates the cmor environment itself at the compute node) by:
```shell
sbatch submit-cmorMDfixer.sh
```

## 3. Adjust the version directory name

##### Adjust the version directory name after the cmorMDfixer.py script has been applied

First run the `version.sh` script, for its help use:
```shell
./versions.sh -h
```
In order to see whether there is more than one version in your data:
```shell
./versions.sh -l CMIP6/
```
If so (this happens when during running the script the date changed because you crossed midnight), you need to set one version (you can choose what you want, but it should be a different and later date than the one which was previously published). One can set the date for instance to September 20 2024 by:
```shell
./versions.sh -v v20240920 -m CMIP6/
```

## 4. Convert an existing CMIP6 directory tree to CMIP6Plus

The ``convert-cmor-table-var-in-drs-and-metadata.sh`` script changes variable and table names to CMIP6Plus standards, updates attributes and adjusts the DRS.

```shell
Usage: ./convert-cmor-table-var-in-drs-and-metadata.sh [-h] [-d] [-v] [-p output_path] [-o] [-s switch_model] [-l log_file] [-c config_file] DIR
    -h : show help message
    -d : don't duplicate data (default: copy data)
    -v : switch on verbose (default: off)
    -p : specify an output path (default: False)
    -o : overwrite existing files (default: False)
    -s : switch to another model (default: False), only affects unregistered cases
    -l : log_file (default: ./convert-cmor-table-var-in-drs-and-metadata.log)
    -c : configuration file (default: convert-ecearth.cfg)
    DIR : path to CMIP6 directory
```

With the configuration file it is possible to add a collection of new global attributes to the converted CMIP6Plus metadata. The example config file adds a comment attribute providing a reference to the OptimESM project and to the authors providing this dataset. Copy this file and edit settings for your model, then launch the conversion with ``-c your_config_file.cfg``

The attributes which are subject to changes when converting from CMIP6 to CMIP6Plus are updated automatically by a direct lookup in the CMIP6Plus CV file.
and don't need to be included in the config file:
- mip_era
- parent_mip_era
- further_info_url (will be removed for CMIP6Plus)
- variable_id
- table_id
- description (new attribute for CMIP6Plus)
- experiment
- license
- institution
- source
- title
- history

Without the ``-d`` option the script copies data from an existing CMIP6 to a CMIP6Plus directory. With ``-d`` the files are moved instead, no backup. Use with caution!

Datasets in the CMIP6 directory that cannot be mapped to CMIP6Plus datasets will be left untouched. In case a CMIP6Plus unregistered model or unregistered experiment is encountered, datasets will be excluded. The ``-s`` switch model option can replace your (CMIP6) model name with a CMIP6Plus registered model name, but this is of course in general not likely a correct situation.



