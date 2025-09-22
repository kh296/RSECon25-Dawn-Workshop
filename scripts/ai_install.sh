#!/bin/bash
#SBATCH --job-name=ai_install   # create a short name for your job
#SBATCH --output=%x.log         # job output file
#SBATCH --partition=pvc9        # cluster partition to be used
#SBATCH --nodes=1               # number of nodes
#SBATCH --gres=gpu:1            # number of allocated gpus per node
#SBATCH --time=02:00:00         # total run time limit (HH:MM:SS)

# Script for installing AI frameworks on Dawn supercomputer,
# including user installation of pytorch (version 2.8).
# Note: Installing multiple frameworks in a single environment risks
# creating conflicts.  Only limited functionality of the installed
# frameworks has been tested.
#
# This installation relies on the user having a conda installation
# at ${CONDA_HOME}/bin/activate.  If not set by the user, CONDA_HOME
# defaults to ${HOME}/miniforge3.  For instructions for installing
# the miniforge3 flagour of conda, see: https://conda-forge.org/download/
#
# After installation, the environment for running lightning applications
# can be activated by sourcing the file ai-setup.sh, created
# in th directory where this script is run.
#
# This script may be run interactively on a Dawn compute node
# (not on a login node):
# bash ./ai_install.sh
# or it may be run on the Slurm batch system:
# sbatch --acount=<project account> ./ai_install.sh

# Exit at first failure.
set -e

T0=${SECONDS}
ENV_NAME="ai"
SOFTWARE="AI frameworks"
echo "Installation of ${SOFTWARE} started: $(date)"
if [ -z "${CONDA_HOME}" ]; then
    if [ -z "${CONDA_PREFIX}" ]; then
        CONDA_HOME=${HOME}/miniforge3
    else
        CONDA_HOME=${CONDA_PREFIX}
    fi
fi

if ! [ -d "${CONDA_HOME}" ]; then
    echo "Conda installation not found at '${CONDA_HOME}' - exiting"
    exit
fi

# Create script for environment setup.
cat <<EOF >${ENV_NAME}-setup.sh
# Setup script for ${SOFTWARE} on Dawn supercomputer.
# Generated: $(date)

module purge
module load rhel9/default-dawn
module load intel-oneapi-mkl
module load intel-oneapi-compilers

# Initialise conda.
source $(realpath ${CONDA_HOME})/bin/activate

# Activate environment.
EOF

# Define installation environment.
source ${ENV_NAME}-setup.sh

# Create and activate conda environment.
#
# Package intelpython3_full provides Intel distribution for Python - see:
# https://www.intel.com/content/www/us/en/developer/tools/oneapi/distribution-python-download.html
#
# Installation of PyTorch based on instructions at:
# https://pytorch-extension.intel.com/installation?platform=gpu&version=v2.8.10%2Bxpu&os=linux%2Fwsl2&package=pip
#
# Instllation of Lightning based on instructions at:
# https://gitlab.developers.cam.ac.uk/kh296/lightning-xpu
#
# Installation of TensorFlow based on instructions at:
# https://github.com/intel/intel-extension-for-tensorflow
#
# Installation of JAX based on instructions at:
# https://github.com/intel/intel-extension-for-openxla/blob/main/docs/acc_jax.md
#
# Package level-zero needed for TensorFlow - see:
# https://github.com/oneapi-src/level-zero/issues/125
cat <<EOF >${ENV_NAME}.yml
name: ${ENV_NAME}
channels:
  - https://software.repos.intel.com/python/conda
  - conda-forge
  - nodefaults
dependencies:
  - intelpython3_full
#  - level-zero
  - python=3.12
  - pip
  - pip:
    - --index-url https://download.pytorch.org/whl/xpu
    - --extra-index-url https://pypi.org/simple
#    - tensorflow==2.15.0
#    - intel-extension-for-tensorflow[xpu]
# Package for IPython kernel creation.
    - ipykernel
# PyTorch
    - torch==2.8.0
    - torchaudio==2.8.0
    - torchvision==0.23.0
# Lightning
    - lightning[extra]
    - litmodels
    - git+https://gitlab.developers.cam.ac.uk/kh296/lightning-xpu#egg=lightning_xpu
# JAX
    - intel-extension-for-openxla
    - -r https://raw.githubusercontent.com/intel/intel-extension-for-openxla/main/test/requirements.txt
EOF

if [ -d "${CONDA_HOME}/envs/${ENV_NAME}" ]; then
    echo ""
    echo "Removing existing environment: ${ENV_NAME}."
    conda env remove -n ${ENV_NAME} -y
fi
echo ""
echo "Creating environment: ${ENV_NAME}."
conda env create -f ${ENV_NAME}.yml
CMD="conda activate ${ENV_NAME}"
echo "${CMD}" >> "${ENV_NAME}-setup.sh"
eval "${CMD}"
python -m pip install --upgrade pip
# Installing JAX last seems to be best way of avoiding conflicts.
# Needs more checking.
#python -m pip install intel-extension-for-openxla
#python -m pip install -r https://raw.githubusercontent.com/intel/intel-extension-for-openxla/main/test/requirements.txt

CMD="python -c 'import lightning_xpu; import lightning; import litmodels; import torch; import torchvision; import torchaudio; import jax'"
echo ""
echo "Performing initial imports:"
echo "${CMD}"
eval "${CMD}"

CMD="python -m ipykernel install --user --name=${ENV_NAME}"
echo ""
echo "Creating Jupyter kernel:"
echo "${CMD}"
eval "${CMD}"

CMD="chmod -R g=u-w ${CONDA_HOME}/envs/ai"
echo ""
echo "Setting group permissions:"
echo "${CMD}"
eval "${CMD}"

echo ""
echo "${SOFTWARE} installation completed: $(date)"
echo "Installation time: $((${SECONDS}-${T0})) seconds"
