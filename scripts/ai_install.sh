#!/bin/bash
#SBATCH --job-name=ai_install   # create a short name for your job
#SBATCH --output=%x.log         # job output file
#SBATCH --partition=pvc9        # cluster partition to be used
#SBATCH --nodes=1               # number of nodes
#SBATCH --gres=gpu:1            # number of allocated gpus per node
#SBATCH --time=02:00:00         # total run time limit (HH:MM:SS)

# Script for installing AI frameworks, for use on Dawn supercomputer,
# and on other systems.  This includes installation of pytorch (version 2.8),
# lightning, and jax.
# Note: Installing multiple frameworks in a single environment risks
# creating conflicts.  Only limited functionality of the installed
# frameworks has been tested.
#
# This installation relies on the user having a conda installation
# at ${CONDA_HOME}/bin/activate.  If not set by the user, CONDA_HOME
# defaults to ${HOME}/miniforge3.  For instructions for installing
# the Miniforge3 flavour of conda, see: https://conda-forge.org/download/
#
# After installation, the environment for using pytorch, lightning, and/or
# jax code can be activated by sourcing the file ai-setup.sh, created
# in the directory ../envs relative to where the current script is run.
#
# On Dawn, the current script may be run interactively on a compute node
# (not on a login node):
# bash ./ai_install.sh
# or it may be submitted from a login node to the Slurm batch system:
# sbatch --account=<project account> ./ai_install.sh
#

# Exit at first failure.
set -e

# Determine system being used.
SOFTWARE="AI frameworks"
if [[ "$(hostname)" == "pvc-s"* ]]; then
    SYSTEM="Dawn"
elif [[ "${OSTYPE}" == "darwin"* ]]; then
    SYSTEM="macOS"
else
    echo "Installation of ${SOFTWARE} for ${OSTYPE} on $(hostname) not handled"
    echo "Exiting: $(date)"
    exit 1
fi

# Check that conda is available.
if [ -z "${CONDA_HOME}" ]; then
    if [ -z "${CONDA_PREFIX}" ]; then
        CONDA_HOME=${HOME}/miniforge3
    else
        CONDA_HOME=${CONDA_PREFIX}
    fi
fi

if ! [ -d "${CONDA_HOME}" ]; then
    echo "Conda installation not found at ${CONDA_HOME}"
    echo "Exiting: $(date)"
    exit 2
fi

# Perform installation.
echo "Installation of ${SOFTWARE} for ${OSTYPE} on $(hostname) started: $(date)"
T0=${SECONDS}
ENV_NAME="ai"

# Create script for environment setup.
ENVS_DIR=$(realpath ..)/envs
mkdir -p ${ENVS_DIR}
SETUP="${ENVS_DIR}/${ENV_NAME}-setup.sh"
DAWN_SETUP="/dev/null"
MACOS_SETUP="/dev/null"
if [[ "Dawn" == "${SYSTEM}" ]]; then
    DAWN_SETUP="${SETUP}"
elif [[ "macOS" == "${SYSTEM}" ]]; then
    MACOS_SETUP="${SETUP}"
fi

cat <<EOF >${SETUP}
# Setup script for ${SOFTWARE} on ${SYSTEM}.
# Generated: $(date)

EOF

cat <<EOF >>${DAWN_SETUP}
# Load modules.
module purge
module load rhel9/default-dawn
module load intel-oneapi-mkl/2025.1.0
module load intel-oneapi-ccl/2021.15.0
module load intel-oneapi-compilers/2025.1.0

#
# Set level-zero environment variables:
# https://oneapi-src.github.io/level-zero-spec/level-zero/latest/core/PROG.html#environment-variables
#

# Define device hierarchy model and affinity mask.
# See: https://www.intel.com/content/www/us/en/developer/articles/technical/flattening-gpu-tile-hierarchy.html
# Define whether a GPU is treated as a single root device ("COMPOSITE")
# or as a root device per stack ("FLAT").
export ZE_FLAT_DEVICE_HIERARCHY="FLAT"
# Define root devices per node to be made visible to applications.
# (Dawn has 4 GPUs per node, and two stacks per GPU.)
export ZE_AFFINITY_MASK="0,1,2,3,4,5,6,7"

#
# Set some variables relevant to Intel MPI Library:
# https://www.intel.com/content/www/us/en/docs/mpi-library/developer-reference-linux/2021-15/environment-variable-reference.html
#

# Set variables relating to GPU support.
# See: https://www.intel.com/content/www/us/en/docs/mpi-library/developer-reference-linux/2021-15/gpu-support.html
# Disable/enable GPU support (default: 0).
export I_MPI_OFFLOAD=1
# Enable/disable assumption that all buffers in an operation have the same type
# (deault: 0).
export I_MPI_OFFLOAD_SYMMETRIC=0

# Set hydra environment variables.
# See: https://www.intel.com/content/www/us/en/docs/mpi-library/developer-reference-linux/2021-15/hydra-environment-variables.html
# Disable/enable process placement provided by job scheduler (default:1)
export I_MPI_JOB_RESPECT_PROCESS_PLACEMENT=0
# Set bootstrap server (default:"ssh")
export I_MPI_HYDRA_BOOTSTRAP="ssh"

#
# Set some variables relevant to OneAPI collective communications library
# (oneCCL):
# https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-ze-ipc-exchange
#

# Select transport for inter-process communication (default: "mpi").
# See: https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-atl-transport
export CCL_ATL_TRANSPORT="ofi"

# Set CCL log level (default: "warn").
# See: https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-log-level
export CCL_LOG_LEVEL="warn"

# Set CCL process launcher (default: "hydra).
# See: https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-process-launcher
export CCL_PROCESS_LAUNCHER="hydra"

# Set mechanism for CCL level zero inter-process communications
# (default: pidfd).
# See: https://uxlfoundation.github.io/oneCCL/env-variables.html#ccl-ze-ipc-exchange
export CCL_ZE_IPC_EXCHANGE=pidfd

# Avoid CCL warning:
# [CCL_WARN] CCL_CONFIGURATION_PATH_modshare=:1 is unknown to and unused by
# oneCCL code but is present in the environment, check if it is not mistyped.
unset CCL_CONFIGURATION_PATH_modshare

EOF

cat <<EOF >>${MACOS_SETUP}
# Initialise environment variables that may be used at run time.
# Define network interface.
export GLOO_SOCKET_IFNAME="en0"

EOF

cat <<EOF >>${SETUP}
# Initialise conda.
source $(realpath ${CONDA_HOME})/bin/activate

# Activate environment.
EOF

# Set up installation environment.
source ${SETUP}
conda update -n base -c conda-forge conda

# Create system-dependent installation file.
#
# Package intelpython3_full provides Intel distribution for Python - see:
# https://www.intel.com/content/www/us/en/developer/tools/oneapi/distribution-python-download.html
#
# Installation of PyTorch on Dawn based on instructions at:
# https://pytorch-extension.intel.com/installation?platform=gpu&version=v2.8.10%2Bxpu&os=linux%2Fwsl2&package=pip
# Installation of PyTorch on other systems based on instructions at:
# https://pytorch.org/get-started/locally/
#
# Instllation of Lightning based on instructions at:
# https://gitlab.developers.cam.ac.uk/kh296/lightning-xpu
#
# Installation of JAX on Dawn based on instructions at:
# https://github.com/intel/intel-extension-for-openxla/blob/main/docs/acc_jax.md
# Installation of JAX on macOS based on instructions at:
# https://developer.apple.com/metal/jax/

CONDA_YML="${ENV_NAME}.yml"
DAWN_CONDA_YML="/dev/null"
MACOS_CONDA_YML="/dev/null"
if [[ "Dawn" == "${SYSTEM}" ]]; then
    DAWN_CONDA_YML="${CONDA_YML}"
elif [[ "macOS" == "${SYSTEM}" ]]; then
    MACOS_CONDA_YML="${CONDA_YML}"
fi

cat <<EOF >"${CONDA_YML}"
name: ${ENV_NAME}
channels:
EOF
cat <<EOF >>"${DAWN_CONDA_YML}"
  - https://software.repos.intel.com/python/conda
EOF
cat <<EOF >>"${CONDA_YML}"
  - conda-forge
  - nodefaults
dependencies:
EOF
cat <<EOF >>"${DAWN_CONDA_YML}"
  - intelpython3_full
EOF
cat <<EOF >>"${CONDA_YML}"
  - python=3.12
  - pip
  - pip:
EOF
cat <<EOF >>"${DAWN_CONDA_YML}"
    - --index-url https://download.pytorch.org/whl/xpu
    - --extra-index-url https://pypi.org/simple
EOF
cat <<EOF >>"${CONDA_YML}"
# IPython kernel creation
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
EOF
cat <<EOF >>"${DAWN_CONDA_YML}"
    - intel-extension-for-openxla
    - -r https://raw.githubusercontent.com/intel/intel-extension-for-openxla/main/test/requirements.txt
EOF
cat <<EOF >>"${MACOS_CONDA_YML}"
    - jax-metal
    - jaxlib
    - jax
EOF

# Delete any pre-existing environment.
if [ -d "${CONDA_HOME}/envs/${ENV_NAME}" ]; then
    echo ""
    echo "Removing existing environment: ${ENV_NAME}."
    conda env remove -n ${ENV_NAME} -y
fi

# Create and activate the environment.
echo ""
echo "Creating environment: ${ENV_NAME}."
conda env create -f ${ENV_NAME}.yml
CMD="conda activate ${ENV_NAME}"
echo "${CMD}" >> "${SETUP}"
eval "${CMD}"
python -m pip install --upgrade pip

# Check installation by importing modules.
CMD="python -c 'import lightning_xpu; import lightning; import litmodels; import torch; import torchvision; import torchaudio; import jax'"
echo ""
echo "Performing initial imports:"
echo "${CMD}"
eval "${CMD}"

# Create Jupyter kernel in default location.
CMD="python -m ipykernel install --user --name=${ENV_NAME}"
echo ""
echo "Creating Jupyter kernel:"
echo "${CMD}"
eval "${CMD}"

echo ""
echo "Installation of ${SOFTWARE} for ${OSTYPE} on $(hostname) completed: $(date)"
echo "Installation time: $((${SECONDS}-${T0})) seconds"

echo ""
echo "Set up environment for ${SOFTWARE} with:"
echo "source ${SETUP}"
echo ""
echo "To use ${SOFTWARE} from Jupyter notebook, choose kernel: ${ENV_NAME}"
